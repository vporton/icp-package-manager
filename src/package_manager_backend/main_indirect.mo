/// Canister that takes on itself potentially non-returning calls.
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Cycles "mo:base/ExperimentalCycles";
import Itertools "mo:itertools/Iter";
import Common "../common";
import Install "../install";
import IC "mo:ic";
import SimpleIndirect "simple_indirect";
import LIB "mo:icpack-lib";
import CyclesLedger "canister:cycles_ledger";
import Battery "battery";

shared({caller = initialCaller}) actor class MainIndirect({
    packageManager: Principal; // may be the bootstrapper instead.
    mainIndirect: Principal;
    simpleIndirect: Principal;
    battery: Principal;
    user: Principal;
    installationId = _: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // let ?userArgValue: ?{
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    stable var initialized = false;

    // stable var _ownersSave: [(Principal, ())] = []; // We don't ugrade this package
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManager, ()),
                (mainIndirect, ()),
                (simpleIndirect, ()),
                (battery, ()),
                (user, ()),
            ].vals(),
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({
        installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManager: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`. // TODO@P3: needed?

        let pm: OurPMType = actor (Principal.toText(packageManager));
        let battery = await pm.getModulePrincipal(installationId, "battery");
        owners.put(battery, ());

        initialized := true;
    };

    public query func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async () {
        if (not initialized) {
            Debug.trap("main_indirect: not initialized");
        };
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
    };

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        onlyOwner(caller, "setOwners");

        owners := HashMap.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Array.size(newOwners),
            Principal.equal,
            Principal.hash,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        onlyOwner(caller, "addOwner");

        owners.put(newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        onlyOwner(caller, "removeOwner");

        owners.delete(oldOwner);
    };

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        };
    };

    type OurPMType = actor {
        getNewCanisterCycles: () -> async Nat; // TODO@P3: seems unneeded
        getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
    };

    /*stable*/ var ourPM: OurPMType = actor (Principal.toText(packageManager)); // actor("aaaaa-aa");
    // /*stable*/ var ourSimpleIndirect = simpleIndirect;

    public shared({caller}) func setOurPM(pm: Principal): async () {
        onlyOwner(caller, "setOurPM");

        ourPM := actor(Principal.toText(pm));
    };

    /// Internal.
    public shared({caller}) func installPackagesWrapper({ // TODO@P3: Rename.
        pmPrincipal: Principal;
        packages: [{
            repo: Common.RepositoryRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
            arg: Blob;
            initArg: ?Blob;
        }];
        minInstallationId: Common.InstallationId;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        bootstrapping: Bool;
    }): () {
        try {
            onlyOwner(caller, "installPackagesWrapper");

            let packages2 = Array.init<?Common.PackageInfo>(Array.size(packages), null);
            for (i in packages.keys()) {
                // unsafe operation, run in main_indirect:
                let pkg = await packages[i].repo.getPackage(packages[i].packageName, packages[i].version);
                packages2[i] := ?(Common.unsharePackageInfo(pkg));
            };

            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                installStart: ({
                    minInstallationId: Common.InstallationId;
                    afterInstallCallback: ?{
                        canister: Principal; name: Text; data: Blob;
                    };
                    user: Principal;
                    packages: [{
                        package: Common.SharedPackageInfo;
                        repo: Common.RepositoryRO;
                        preinstalledModules: [(Text, Principal)];
                        arg: Blob;
                        initArg: ?Blob;
                    }];
                    bootstrapping: Bool;
                }) -> async ();
            };

            // TODO@P3: The following can't work during bootstrapping, because we are `bootstrapper`. But bootstrapping succeeds.
            let cyclesAmount = await ourPM.getNewCanisterCycles(); // TODO@P3: Don't call it several times.
            let totalCyclesAmount = if (minInstallationId == 0) { // TODO@P3: The condition is a hack.
                0; // We use the bootstrapper cycles, not battery.
            } else {
                (cyclesAmount + 100_000_000_000) * Itertools.fold<?Common.PackageInfo, Nat>( // TODO@P2: 100_000_000_000 is install_code() amount.
                    packages2.vals(), 0, func (acc: Nat, pkg: ?Common.PackageInfo) {
                        let ?pkg2 = pkg else {
                            Debug.trap("programming error");
                        };
                        let #real specific = pkg2.specific else {
                            // TODO@P3: Support virtual packages.
                            Debug.trap("programming error");
                        };
                        acc + specific.modules.size()
                    });
            };
            let batteryActor: Battery.Battery = actor(Principal.toText(battery));
            // Cycles go to `mainIndirect`, instead:
            if (totalCyclesAmount != 0) {
                await batteryActor.withdrawCycles3(totalCyclesAmount, mainIndirect);
            };
            await /*(with cycles = totalCyclesAmount)*/ pm.installStart({ // Cycles are already delivered to `main_indirect`.
                minInstallationId;
                afterInstallCallback;
                user;
                packages = Iter.toArray(Iter.map<Nat, {
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryRO;
                    preinstalledModules: [(Text, Principal)];
                    arg: Blob;
                    initArg: ?Blob;
                }>(
                    packages.keys(),
                    func (i: Nat) = do {
                        let ?pkg = packages2[i] else {
                            Debug.trap("programming error");
                        };
                        {
                            package = Common.sharePackageInfo(pkg);
                            repo = packages[i].repo;
                            preinstalledModules = packages[i].preinstalledModules;
                            arg = packages[i].arg;
                            initArg = packages[i].initArg;
                        };
                    },
                ));
                bootstrapping;
            });
        }
        catch (e) {
            Debug.print("installPackagesWrapper: " # Error.message(e));
            Debug.trap(Error.message(e));
        };
    };

    public shared({caller}) func installModule({
        installationId: Common.InstallationId;
        moduleNumber: Nat;
        moduleName: ?Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManager: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        preinstalledCanisterId: ?Principal;
        arg: Blob;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async () {
        Debug.print("installModule BALANCE: " # debug_show(Cycles.balance()));
        // TODO@P3: `async` is because we need battery initialized before others.
        // TODO@P2: Check that we are not legible to non-returning-call attack!
        try {
            onlyOwner(caller, "installModule");

            Debug.print("installModule " # debug_show(moduleName) # " preinstalled: " # debug_show(preinstalledCanisterId));

            // TODO@P3: bad code
            switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) {
                    let pm: Install.Callbacks = actor(Principal.toText(packageManager));

                    await pm.onInstallCode({
                        moduleNumber;
                        moduleName;
                        module_ = wasmModule;
                        canister = preinstalledCanisterId;
                        installationId;
                        user;
                        packageManager;
                        afterInstallCallback;
                    });
                };
                case null {
                    ignore await* Install._installModuleCode({
                        installationId;
                        upgradeId = null;
                        moduleNumber;
                        moduleName;
                        wasmModule = Common.unshareModule(wasmModule);
                        arg;
                        packageManager;
                        mainIndirect;
                        simpleIndirect;
                        battery;
                        user;
                        controllers = ?[Principal.fromActor(this), user]; // TODO@P2: `user` was used only for testing.
                        afterInstallCallback;
                    });
                };
            };
        }
        catch (e) {
            let msg = "installModule: " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared({caller}) func upgradePackageWrapper({
        minUpgradeId: Common.UpgradeId;
        packages: [{
            installationId: Common.InstallationId;
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
            arg: Blob;
            initArg: ?Blob;
        }];
        user: Principal;
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): () {
        try {
            onlyOwner(caller, "upgradePackageWrapper");

            let newPackages = Array.init<?Common.PackageInfo>(Array.size(packages), null);
            for (i in packages.keys()) {
                // unsafe operation, run in main_indirect:
                let pkg = await packages[i].repo.getPackage(packages[i].packageName, packages[i].version);
                newPackages[i] := ?(Common.unsharePackageInfo(pkg));
            };

            let backendObj = actor(Principal.toText(packageManager)): actor {
                upgradeStart: shared ({
                    minUpgradeId: Common.UpgradeId;
                    user: Principal;
                    packages: [{
                        installationId: Common.InstallationId;
                        package: Common.SharedPackageInfo;
                        repo: Common.RepositoryRO;
                        arg: Blob;
                        initArg: ?Blob;
                    }];
                    afterUpgradeCallback: ?{
                        canister: Principal; name: Text; data: Blob;
                    };
                }) -> async ();
            };
            await backendObj.upgradeStart({
                minUpgradeId;
                user;
                packages = Iter.toArray(Iter.map<Nat, {
                    installationId: Common.InstallationId;
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryRO;
                    arg: Blob;
                    initArg: ?Blob;
                }>(
                    packages.keys(),
                    func (i: Nat) = do {
                        let ?pkg = newPackages[i] else {
                            Debug.trap("programming error");
                        };
                        {
                            installationId = packages[i].installationId;
                            package = Common.sharePackageInfo(pkg);
                            repo = packages[i].repo;
                            arg = packages[i].arg;
                            initArg = packages[i].initArg;
                        };
                    },
                ));
                afterUpgradeCallback;
            });
        }
        catch (e) {
            Debug.print("upgradePackageWrapper: " # Error.message(e));
        };
    };

    public shared({caller}) func upgradeOrInstallModule({
        upgradeId: Common.UpgradeId;
        installationId: Common.InstallationId;
        moduleNumber: Nat;
        moduleName: Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManager: Principal;
        simpleIndirect: Principal;
        arg: Blob;
        canister_id: ?Principal;
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): () {
        try {
            onlyOwner(caller, "upgradeOrInstallModule");

            Debug.print("upgradeOrInstallModule " # debug_show(moduleName) # " " # debug_show(upgradeId));

            let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
            let repository: Common.RepositoryRO =
                actor(Principal.toText(wasmModuleLocation.0));

            let wasm_module = await repository.getWasmModule(wasmModuleLocation.1);
            let newCanisterId = switch (canister_id) {
                case (?canister_id) {
                    let mode2 = if (wasmModule.forceReinstall) {
                        #reinstall
                    } else {
                        #upgrade (?{ wasm_memory_persistence = ?#keep; skip_pre_upgrade = ?false });
                    };
                    let simple: SimpleIndirect.SimpleIndirect = actor(Principal.toText(simpleIndirect));
                    await simple.install_code({ // TODO@P2: Manage cycles.
                        sender_canister_version = null; // TODO@P3: Set appropriate value.
                        arg = to_candid({
                            packageManager;
                            mainIndirect;
                            simpleIndirect;
                            user;
                            installationId;
                            upgradeId;
                            userArg = arg;
                        });
                        wasm_module;
                        mode = mode2;
                        canister_id;
                    }, 1000_000_000_000); // TODO@P3
                    canister_id;
                };
                case null {
                    let {canister_id} = await* Install.myCreateCanister({
                        controllers = ?[Principal.fromActor(this), simpleIndirect];
                        subnet_selection = null;
                        cycles = await ourPM.getNewCanisterCycles(); // TODO@P2: How many cycles?
                    });
                    await* Install.myInstallCode({
                        installationId;
                        upgradeId = null;
                        canister_id;
                        wasmModule = Common.unshareModule(wasmModule);
                        arg = to_candid({
                            moduleNumber;
                            // TODO@P3
                            userArg = arg;
                        });
                        packageManager;
                        mainIndirect;
                        simpleIndirect;
                        battery;
                        user;
                    });

                    // Remove `mainIndirect` as a controller, because it's costly to replace it in every canister after new version of `mainIndirect`..
                    // Note that packageManager calls it on getMainIndirect(), not by itself, so doesn't freeze.
                    let simple: SimpleIndirect.SimpleIndirect = actor(Principal.toText(simpleIndirect));
                    await simple.update_settings({ // the actor that is a controller
                        canister_id;
                        sender_canister_version = null; // TODO@P3: Set appropriate value.
                        settings = {
                            compute_allocation = null;
                            controllers = ?[simpleIndirect, user];
                            freezing_threshold = null;
                            log_visibility = null;
                            memory_allocation = null;
                            reserved_cycles_limit = null;
                            wasm_memory_limit = null;
                        };
                    }, 1000_000_000_000); // TODO@P3
                    canister_id;
                };
            };
            let backendObj = actor (Principal.toText(packageManager)) : actor {
                onUpgradeOrInstallModule: shared ({
                    upgradeId: Common.UpgradeId;
                    moduleName: Text;
                    canister_id: Principal;
                    afterUpgradeCallback: ?{
                        canister: Principal; name: Text; data: Blob;
                    };
                }) -> async ();
            };
            await backendObj.onUpgradeOrInstallModule({upgradeId; moduleName; canister_id = newCanisterId; afterUpgradeCallback});
            await* Install.copyAssetsIfAny({
                wasmModule = Common.unshareModule(wasmModule); // TODO@P3: duplicate call above
                canister_id = newCanisterId;
                simpleIndirect;
                user;
            });
        }
        catch (e) {
            Debug.print("upgradeOrInstallModule: " # Error.message(e));
        };
    };

    /// Internal.
    public shared({caller}) func topUpOneCanisterFinish(canister_id: Principal, fulfillment: Common.CanisterFulfillment): () {
        try {
            onlyOwner(caller, "topUpOneCanisterFinish");

            let status = await IC.ic.canister_status({canister_id});
            let remaining = status.cycles;
            if (remaining <= fulfillment.threshold) {
                ignore Cycles.accept<system>(fulfillment.topupAmount);
                Cycles.add<system>(fulfillment.topupAmount);
                await IC.ic.deposit_cycles({canister_id});
            };
        }
        catch (e) {
            Debug.print("topUpOneCanisterFinish: " # Error.message(e));
        };
    };

//     public composite query({caller}) func checkCodeInstalled({
//         canister_ids: [Principal];
//     }): async Bool {
//         try {
//             onlyOwner(caller, "checkCodeInstalled");

//             type Callee = {
//                 b44c4a9beec74e1c8a7acbe46256f92f_isInitialized: query () -> async ();
//             };

//             let threads : [var async()] = Array.tabulateVar(Array.size(canister_ids), func (i: Nat) = func(i: Nat): async () {
//                 let a: Callee = actor(Principal.toText(canister_ids[i]));
//                 a.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
//             });
//             // let threads : [var ?(async())] = Array.init(Array.size()canister_ids, null);
//             // for (i in threads.keys()) {
//             //     threads[i] := ?runThread();
//             // };     
//             // for (topt in threads.vals()) {
//             //     let ?t = topt;
//             //     await t;
//             // }

//             // let status = await IC.ic.canister_status({ canister_id });
//             // Option.isSome(status.module_hash);
//         }
//         catch (e) {
//             let msg = "checkCodeInstalled: " # Error.message(e);
//             Debug.print(msg);
//             Debug.trap(msg);
//         };
//    };

    public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
        await* LIB.withdrawCycles(CyclesLedger, amount, payee, caller);
    };
}