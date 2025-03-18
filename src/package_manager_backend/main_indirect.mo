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
import Common "../common";
import Install "../install";
import IC "mo:ic";
import SimpleIndirect "simple_indirect";

shared({caller = initialCaller}) actor class MainIndirect({
    packageManagerOrBootstrapper: Principal; // TODO: Rename to just `packageManager`?.
    mainIndirect: Principal; // TODO: Rename.
    simpleIndirect: Principal;
    user: Principal;
    installationId = _: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    stable var initialized = false;

    // stable var _ownersSave: [(Principal, ())] = []; // We don't ugrade this package
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (mainIndirect, ()),
                (simpleIndirect, ()),
                (user, ()),
            ].vals(),
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({
        installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManagerOrBootstrapper: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`. // TODO: needed?

        let pm: OurPMType = actor (Principal.toText(packageManagerOrBootstrapper));
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
        getNewCanisterCycles: () -> async Nat; // TODO: seems unneeded
        getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
    };

    /*stable*/ var ourPM: OurPMType = actor (Principal.toText(packageManagerOrBootstrapper)); // actor("aaaaa-aa");
    // /*stable*/ var ourSimpleIndirect = simpleIndirect;

    public shared({caller}) func setOurPM(pm: Principal): async () {
        onlyOwner(caller, "setOurPM");

        ourPM := actor(Principal.toText(pm));
    };

    public shared({caller}) func installPackagesWrapper({ // TODO: Rename.
        pmPrincipal: Principal;
        packages: [{
            repo: Common.RepositoryRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
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
                    }];
                    bootstrapping: Bool;
                }) -> async ();
            };

            // TODO: The following can't work during bootstrapping, because we are `bootstrapper`. But bootstrapping succeeds.
            await pm.installStart({
                minInstallationId;
                afterInstallCallback;
                user;
                packages = Iter.toArray(Iter.map<Nat, {
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryRO;
                    preinstalledModules: [(Text, Principal)];
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
                        };
                    },
                ));
                bootstrapping;
            });
        }
        catch (e) {
            Debug.print("installPackagesWrapper: " # Error.message(e));
            throw e;
        };
    };

    private type Callbacks = actor {
        onCreateCanister: shared ({
            installationId: Common.InstallationId;
            moduleNumber: Nat;
            moduleName: ?Text;
            canister: Principal;
            user: Principal;
        }) -> async ();
        onInstallCode: shared ({
            installationId: Common.InstallationId;
            canister: Principal;
            moduleNumber: Nat;
            moduleName: ?Text;
            user: Principal;
            module_: Common.SharedModule;
            packageManagerOrBootstrapper: Principal;
            afterInstallCallback: ?{
                canister: Principal; name: Text; data: Blob;
            };
        }) -> async ();
    };

    public shared({caller}) func installModule({
        installationId: Common.InstallationId;
        moduleNumber: Nat;
        moduleName: ?Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        preinstalledCanisterId: ?Principal;
        installArg: Blob;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): () {
        try {
            onlyOwner(caller, "installModule");

            Debug.print("installModule " # debug_show(moduleName) # " preinstalled: " # debug_show(preinstalledCanisterId));

            switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) {
                    let cb: Callbacks = actor (Principal.toText(packageManagerOrBootstrapper));
                    await cb.onInstallCode({
                        installationId;
                        moduleNumber;
                        moduleName;
                        module_ = wasmModule;
                        canister = preinstalledCanisterId;
                        user;
                        packageManagerOrBootstrapper;
                        afterInstallCallback;
                    });
                };
                case null {
                    ignore await* _installModuleCode({
                        installationId;
                        upgradeId = null;
                        moduleNumber;
                        moduleName;
                        wasmModule = Common.unshareModule(wasmModule);
                        installArg;
                        packageManagerOrBootstrapper;
                        mainIndirect;
                        simpleIndirect;
                        user;
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

    // TODO: unused?
    private func _installModuleCode({
        moduleNumber: Nat;
        moduleName: ?Text;
        installationId: Common.InstallationId;
        upgradeId: ?Common.UpgradeId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        installArg: Blob;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async* Principal {
        let {canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this)];
            user;
            mainIndirect;
            cyclesAmount = await ourPM.getNewCanisterCycles(); // TODO: Don't call it several times.
        });

        let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
    
        await* Install.myInstallCode({
            installationId;
            upgradeId;
            canister_id;
            wasmModule;
            installArg;
            packageManagerOrBootstrapper;
            mainIndirect;
            simpleIndirect;
            user;
        });

        // Remove `mainIndirect` as a controller, because it's costly to replace it in every canister after new version of `mainIndirect`..
        // Note that packageManagerOrBootstrapper calls it on getMainIndirect(), not by itself, so doesn't freeze.
        await IC.ic.update_settings({
            canister_id;
            sender_canister_version = null;
            settings = {
                compute_allocation = null;
                controllers = ?[simpleIndirect, user];
                freezing_threshold = null;
                log_visibility = null;
                memory_allocation = null;
                reserved_cycles_limit = null;
                wasm_memory_limit = null;
            };
        });

        await pm.onInstallCode({
            moduleNumber;
            moduleName;
            module_ = Common.shareModule(wasmModule);
            canister = canister_id;
            installationId;
            user;
            packageManagerOrBootstrapper;
            afterInstallCallback;
        });

        canister_id;
    };

    public shared({caller}) func upgradePackageWrapper({
        minUpgradeId: Common.UpgradeId;
        packages: [{
            installationId: Common.InstallationId;
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
        // pmPrincipal: Principal; // TODO
        user: Principal;
        arg: Blob;
    }): () {
        try {
            onlyOwner(caller, "upgradePackageWrapper");

            let newPackages = Array.init<?Common.PackageInfo>(Array.size(packages), null);
            for (i in packages.keys()) {
                // unsafe operation, run in main_indirect:
                let pkg = await packages[i].repo.getPackage(packages[i].packageName, packages[i].version);
                newPackages[i] := ?(Common.unsharePackageInfo(pkg));
            };

            let backendObj = actor(Principal.toText(packageManagerOrBootstrapper)): actor {
                upgradeStart: shared ({
                    minUpgradeId: Common.UpgradeId;
                    user: Principal;
                    packages: [{
                        installationId: Common.InstallationId;
                        package: Common.SharedPackageInfo;
                        repo: Common.RepositoryRO;
                    }];
                }) -> async ();
            };
            await backendObj.upgradeStart({
                minUpgradeId;
                user;
                packages = Iter.toArray(Iter.map<Nat, {
                    installationId: Common.InstallationId;
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryRO;
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
                        };
                    },
                ));
                arg;
            });
        }
        catch (e) {
            Debug.print("upgradePackageWrapper: " # Error.message(e));
        };
    };

    public shared({caller}) func upgradeOrInstallModule({
        upgradeId: Common.UpgradeId;
        installationId: Common.InstallationId;
        moduleNumber: Nat; // TODO
        moduleName: Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        simpleIndirect: Principal;
        installArg: Blob;
        upgradeArg: Blob;
        canister_id: ?Principal;
    }): () {
        try {
            onlyOwner(caller, "upgradeOrInstallModule");

            Debug.print("upgradeOrInstallModule " # debug_show(moduleName));

            let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
            let wasmModuleSourcePartition: Common.RepositoryRO =
                actor(Principal.toText(wasmModuleLocation.0)); // TODO: Rename if needed

            let wasm_module = await wasmModuleSourcePartition.getWasmModule(wasmModuleLocation.1);
            let newCanisterId = switch (canister_id) {
                case (?canister_id) {
                    let mode2 = if (wasmModule.forceReinstall) {
                        #reinstall
                    } else {
                        #upgrade (?{ wasm_memory_persistence = ?#keep; skip_pre_upgrade = ?false }); // TODO: Check modes carefully.
                    };
                    // TODO: consider invoking user's callback if needed.
                    let simple: SimpleIndirect.SimpleIndirect = actor(Principal.toText(simpleIndirect));
                    await simple.install_code({
                        sender_canister_version = null; // TODO: set appropriate value if needed.
                        arg = to_candid({
                            packageManagerOrBootstrapper;
                            simpleIndirect;
                            user;
                            installationId;
                            upgradeId;
                            userArg = ?upgradeArg;
                        });
                        wasm_module;
                        mode = mode2;
                        canister_id;
                    }, 1000_000_000_000); // TODO
                    canister_id;
                };
                case null {
                    let {canister_id} = await* Install.myCreateCanister({
                        mainControllers = ?[Principal.fromActor(this), simpleIndirect];
                        user;
                        mainIndirect;
                        cyclesAmount = await ourPM.getNewCanisterCycles();
                    });
                    await* Install.myInstallCode({
                        installationId;
                        upgradeId = null;
                        canister_id;
                        wasmModule = Common.unshareModule(wasmModule);
                        installArg = to_candid(installArg); // TODO: per-module args (here and in other places)
                        packageManagerOrBootstrapper;
                        mainIndirect;
                        simpleIndirect;
                        user;
                    });

                    // Remove `mainIndirect` as a controller, because it's costly to replace it in every canister after new version of `mainIndirect`..
                    // Note that packageManagerOrBootstrapper calls it on getMainIndirect(), not by itself, so doesn't freeze.
                    let simple: SimpleIndirect.SimpleIndirect = actor(Principal.toText(simpleIndirect));
                    await simple.update_settings({ // the actor that is a controller
                        canister_id;
                        sender_canister_version = null;
                        settings = {
                            compute_allocation = null;
                            controllers = ?[simpleIndirect, user];
                            freezing_threshold = null;
                            log_visibility = null;
                            memory_allocation = null;
                            reserved_cycles_limit = null;
                            wasm_memory_limit = null;
                        };
                    }, 1000_000_000_000); // TODO
                    canister_id;
                };
            };
            let backendObj = actor (Principal.toText(packageManagerOrBootstrapper)) : actor {
                onUpgradeOrInstallModule: shared ({
                    upgradeId: Common.UpgradeId;
                    moduleName: Text;
                    canister_id: Principal;
                }) -> async ();
            };
            await backendObj.onUpgradeOrInstallModule({upgradeId; moduleName; canister_id = newCanisterId});
            await* Install.copyAssetsIfAny({
                wasmModule = Common.unshareModule(wasmModule); // TODO: duplicate call above
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
                ignore Cycles.accept<system>(fulfillment.installAmount);
                Cycles.add<system>(fulfillment.installAmount);
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
}