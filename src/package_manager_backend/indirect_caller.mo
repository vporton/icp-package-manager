/// Canister that takes on itself potentially non-returning calls.
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Common "../common";
import Install "../install";

shared({caller = initialCaller}) actor class IndirectCaller({
    packageManagerOrBootstrapper: Principal;
    initialIndirect: Principal; // TODO: Rename.
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
            [ // TODO: Remove unneeded:
                (packageManagerOrBootstrapper, ()),
                (initialIndirect, ()),
                (simpleIndirect, ()),
                (user, ()),
                (Principal.fromActor(this), ()),
            ].vals(),
            5,
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
            Debug.trap("indirect_caller: not initialized");
        };
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
    /*stable*/ var ourSimpleIndirect = simpleIndirect;

    public shared({caller}) func setOurPM(pm: Principal): async () {
        onlyOwner(caller, "setOurPM");

        ourPM := actor(Principal.toText(pm));
    };

    public shared({caller}) func installPackageWrapper({ // TODO: Rename.
        whatToInstall: {
            #package;
            // #simplyModules : [(Text, Common.SharedModule)]; // FIXME: This branch does not work now.
        };
        pmPrincipal: Principal;
        packages: [{
            repo: Common.RepositoryPartitionRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
        }];
        installationId: Common.InstallationId;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): () {
        try {
            onlyOwner(caller, "installPackageWrapper");

            let packages2 = Array.init<?Common.PackageInfo>(Array.size(packages), null);
            for (i in packages.keys()) {
                // unsafe operation, run in indirect_caller:
                let pkg = await packages[i].repo.getPackage(packages[i].packageName, packages[i].version);
                packages2[i] := ?(Common.unsharePackageInfo(pkg));
            };
            let ?package2 = packages2[0] else { // FIXME: This is a temporary code.
                Debug.trap("package not found");
            };

            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                installationWorkCallback: ({
                    whatToInstall: {
                        #package;
                        // #simplyModules : [(Text, Common.SharedModule)]; // TODO
                    };
                    installationId: Common.InstallationId;
                    user: Principal;
                    packages: [{
                        package: Common.SharedPackageInfo;
                        repo: Common.RepositoryPartitionRO;
                        preinstalledModules: [(Text, Principal)];
                    }];
                }) -> async ();
            };

            // TODO: The following can't work during bootstrapping, because we are `Bootstrapper`. But bootstrapping succeeds.
            await pm.installationWorkCallback({
                whatToInstall; /// install package or named modules.
                installationId;
                user;
                packages = Iter.toArray(Iter.map<Nat, {
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryPartitionRO;
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
            });

            for (p0 in packages.keys()) {
                let ?p = packages2[p0] else {
                    Debug.trap("programming error");
                };
                let modules: Iter.Iter<(Text, Common.Module)> = switch (whatToInstall) {
                    // case (#simplyModules m) {
                    //     Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                    //         m.vals(),
                    //         func (p: (Text, Common.SharedModule)) = (p.0, Common.unshareModule(p.1)),
                    //     );
                    // };
                    case (#package) {
                        switch (package2.specific) {
                            case (#real pkgReal) {
                                Iter.filter<(Text, Common.Module)>(
                                    pkgReal.modules.entries(),
                                    func (p: (Text, Common.Module)) = p.1.installByDefault,
                                );
                            };
                            case (#virtual _) [].vals();
                        };
                    }
                };

                let bi = if (packages[p0].preinstalledModules.size() == 0) { // TODO: All this block is a crude hack.
                    [("backend", Principal.fromActor(ourPM)), ("indirect", Principal.fromActor(this)), ("simple_indirect", ourSimpleIndirect)];
                } else {
                    packages[p0].preinstalledModules;
                };
                let coreModules = HashMap.fromIter<Text, Principal>(bi.vals(), bi.size(), Text.equal, Text.hash);
                var moduleNumber = 0;
                let ?backend = coreModules.get("backend") else {
                    Debug.trap("error 1");
                };
                let ?indirect = coreModules.get("indirect") else {
                    Debug.trap("error 1");
                };
                let ?simple_indirect = coreModules.get("simple_indirect") else {
                    Debug.trap("error 1");
                };
                // The following (typically) does not overflow cycles limit, because we use an one-way function.
                for ((name, m): (Text, Common.Module) in modules) {
                    // Starting installation of all modules in parallel:
                    this.installModule({
                        installPackage = whatToInstall == #package; // TODO: correct?
                        moduleNumber;
                        moduleName = ?name;
                        installArg = to_candid({
                            installationId;
                            packageManagerOrBootstrapper = backend;
                        }); // TODO: Add more arguments.
                        installationId;
                        packageManagerOrBootstrapper = backend;
                        initialIndirect = indirect;
                        simpleIndirect = simple_indirect;
                        preinstalledCanisterId = coreModules.get(name);
                        user; // TODO: `!`
                        wasmModule = Common.shareModule(m); // TODO: We unshared, then shared it, huh?
                        afterInstallCallback;
                    });
                    moduleNumber += 1;
                };
            };
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
        installPackage: Bool;
        installationId: Common.InstallationId;
        moduleNumber: Nat;
        moduleName: ?Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        initialIndirect: Principal;
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
                    await cb.onCreateCanister({
                        installPackage;
                        installationId;
                        moduleNumber;
                        moduleName;
                        // module_ = wasmModule;
                        canister = preinstalledCanisterId;
                        user;
                    });
                    await cb.onInstallCode({
                        installPackage;
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
                        installPackage;
                        installArg;
                        packageManagerOrBootstrapper;
                        initialIndirect;
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

    private func _installModuleCode({
        moduleNumber: Nat;
        moduleName: ?Text;
        installPackage: Bool;
        installationId: Common.InstallationId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        initialIndirect: Principal;
        simpleIndirect: Principal;
        installArg: Blob;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async* Principal {
        let {canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[user, initialIndirect, simpleIndirect];
            user;
            initialIndirect;
            cyclesAmount = await ourPM.getNewCanisterCycles(); // TODO: Don't call it several times.
        });

        let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
        await pm.onCreateCanister({
            installPackage; // Bool
            moduleNumber;
            moduleName;
            // module_ = Common.shareModule(wasmModule);
            installationId;
            canister = canister_id;
            user;
        });

        await* Install.myInstallCode({
            installationId;
            canister_id;
            wasmModule;
            installArg;
            packageManagerOrBootstrapper;
            initialIndirect;
            simpleIndirect;
            user;
        });

        await pm.onInstallCode({
            installPackage; // Bool
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