/// Canister that takes on itself potentially non-returning calls.
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Common "../common";
import Install "../install";
import IC "mo:ic";

shared({caller = initialCaller}) actor class MainIndirect({
    packageManagerOrBootstrapper: Principal;
    mainIndirect: Principal; // TODO: Rename.
    simpleIndirect: Principal;
    user: Principal;
    // installationId: Common.InstallationId;
    // userArg: Blob;
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
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManagerOrBootstrapper: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`.

        // ourPM := actor (Principal.toText(packageManagerOrBootstrapper)): OurPMType;
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
        getNewCanisterCycles: () -> async Nat;
    };

    /*stable*/ var ourPM: OurPMType = actor (Principal.toText(packageManagerOrBootstrapper)); // actor("aaaaa-aa");
    // /*stable*/ var ourSimpleIndirect = simpleIndirect;

    public shared({caller}) func setOurPM(pm: Principal): async () {
        onlyOwner(caller, "setOurPM");

        ourPM := actor(Principal.toText(pm));
    };

    public shared({caller}) func installPackageWrapper({ // TODO: Rename.
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
            onlyOwner(caller, "installPackageWrapper");

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

            // TODO: The following can't work during bootstrapping, because we are `Bootstrapper`. But bootstrapping succeeds.
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
            Debug.print("installPackageWrapper: " # Error.message(e));
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
        installPackages: Bool;
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
                        installPackages;
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
                        moduleNumber;
                        moduleName;
                        wasmModule = Common.unshareModule(wasmModule);
                        installPackages;
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
        installPackages: Bool;
        installationId: Common.InstallationId;
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
            installPackages; // Bool
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

    // FIXME: Rewrite.
    shared({caller}) func upgradePackage({
        oldPkg: Common.SharedPackageInfo;
        upgradeId: Common.UpgradeId;
        installationId: Common.InstallationId;
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryRO;
        user: Principal;
        arg: [Nat8];
        backend: Principal;
    }): () {
        onlyOwner(caller, "upgradePackage");

        // FIXME: upgrading a real package into virtual or vice versa
        let newPkg = Common.unsharePackageInfo(await repo.getPackage(packageName, version));
        // TODO: virtual packages
        let oldPkg2 = Common.unsharePackageInfo(oldPkg);
        let #specific oldPkgSpecific = oldPkg2.specific else {
            Debug.trap("trying to directly upgrade a virtual package");
        };
        let #specific newPkgSpecific = newPkg.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        let oldPkgModules = newPkgSpecific.modules;
        let oldPkgModulesHash = HashMap.fromIter<Text, Common.Module>(oldPkgModules.vals(), oldPkgModules.size(), Text.equal, Text.hash);
        let newPkgModules = newPkgSpecific.modules;
        let newPkgModulesHash = HashMap.fromIter<Text, Common.Module>(newPkgModules.vals(), newPkgModules.size(), Text.equal, Text.hash);
        let modulesToDelete = Iter.filter<(Text, Common.Module)>(
            oldPkgSpecific.modules, func (x: (Text, Common.Module)) = Option.isNull(newPkgModulesHash.get(x.0))
        );

        backend.upgradePackageFinish({
            upgradeId;
            installationId;
            package = newPkg;
            namedModules = HashMap.HashMap(0, Text.equal, Text.hash);
            allModules = Buffer.Buffer(0);
            var remainingModules = newPkgModules.size() - modulesToDelete.size();
        });
    };

    private func upgradeOrInstallModuleFinish({
        upgradeId: Common.UpgradeId;
        installationId: Common.InstallationId;
        canister_id: Principal;
        user: Principal;
        wasm_module: Blob;
        mode: {#upgrade; #install};
    }): () {
        await* Install.myInstallCode({
            installationId;
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

        backend.onUpgradeOrInstallModule({ // FIXME
            upgradeId;
            installationId;
            canister_id;
            user;
        });
    }


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