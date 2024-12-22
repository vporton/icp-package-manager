/// Canister that takes on itself potentially non-returning calls.
import ICE "mo:base/ExperimentalInternetComputer";
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
            // FIXME: Remove Bootrapper later.
            [
                // (initialCaller, ()), // for bootstrapper
                (packageManagerOrBootstrapper, ()),
                (initialIndirect, ()),
                (user, ()),
            ].vals(),
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({ // TODO
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

    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
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

    public shared({caller}) func setOurPM(pm: Principal): async () {
        onlyOwner(caller, "setOurPM");

        ourPM := actor(Principal.toText(pm));
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    private func callAllOneWayImpl(methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        label cycle for (method in methods.vals()) {
            try {
                ignore await ICE.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
                break cycle;
            };
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, keep calling other methods.
    ///
    /// TODO: We don't need this function.
    private func callIgnoringMissingOneWayImpl(methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        for (method in methods.vals()) {
            try {
                ignore await ICE.call(method.canister, method.name, method.data);
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
                if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                    throw e; // Other error cause interruption.
                }
            };
        };
    };

    /// TODO: We don't need this function.
    public shared({caller}) func callIgnoringMissingOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller, "callIgnoringMissingOneWay");

        await* callIgnoringMissingOneWayImpl(methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller, "callAllOneWay");

        await* callAllOneWayImpl(methods);
    };

    /// TODO: We don't need this function.
    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller, "callIgnoringMissing");

        try {
            return await ICE.call(method.canister, method.name, method.data); 
        }
        catch (e) {
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared({caller}) func call(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller, "call");

        try {
            return await ICE.call(method.canister, method.name, method.data);
        }
        catch (e) {
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    // public shared({caller}) func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async () {
    //     onlyOwner(caller, "copyAll");

    //     try {
    //         return await* CopyAssets.copyAll({from; to});
    //     }
    //     catch (e) {
    //         Debug.print("Indirect caller copyAll: " # Error.message(e));
    //         Debug.trap("Indirect caller copyAll: " # Error.message(e));
    //     };
    // };

    public shared({caller}) func installPackageWrapper({ // TODO: Rename.
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        repo: Common.RepositoryPartitionRO;
        pmPrincipal: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        installationId: Common.InstallationId;
        preinstalledModules: [(Text, Principal)];
        user: Principal;
    }): () {
        try {
            onlyOwner(caller, "installPackageWrapper");

            let package = await repo.getPackage(packageName, version); // unsafe operation, run in indirect_caller

            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                installationWorkCallback: ({
                    whatToInstall: {
                        #package;
                        #simplyModules : [(Text, Common.SharedModule)];
                    };
                    installationId: Common.InstallationId;
                    user: Principal;
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryPartitionRO;
                    preinstalledModules: [(Text, Principal)];
                }) -> async ();
            };

            // TODO: The following can't work during bootstrapping, because we are `Bootstrapper`. But bootstrapping succeeds.
            await pm.installationWorkCallback({
                whatToInstall; /// install package or named modules.
                installationId;
                user;
                package;
                repo;
                preinstalledModules;
            });

            let modules: Iter.Iter<(Text, Common.Module)> = switch (whatToInstall) {
                case (#simplyModules m) {
                    Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                        m.vals(),
                        func (p: (Text, Common.SharedModule)) = (p.0, Common.unshareModule(p.1)),
                    );
                };
                case (#package) {
                    let pkg = await repo.getPackage(packageName, version); // TODO: should be not here.
                    switch (pkg.specific) {
                        case (#real pkgReal) {
                            Iter.map<(Text, (Common.SharedModule, Bool)), (Text, Common.Module)>(
                                Iter.filter<(Text, (Common.SharedModule, Bool))>(
                                    pkgReal.modules.vals(),
                                    func (p: (Text, (Common.SharedModule, Bool))) = p.1.1,
                                ),
                                func (p: (Text, (Common.SharedModule, Bool))) = (p.0, Common.unshareModule(p.1.0)),
                            );
                        };
                        case (#virtual _) [].vals();
                    };
                }
            };

            let bi = if (preinstalledModules.size() == 0) { // TODO: All this block is a crude hack.
                [("backend", Principal.fromActor(ourPM)), ("indirect", Principal.fromActor(this))];
            } else {
                preinstalledModules;
            };
            let coreModules = HashMap.fromIter<Text, Principal>(bi.vals(), bi.size(), Text.equal, Text.hash);
            var moduleNumber = 0;
            let ?backend = coreModules.get("backend") else {
                Debug.trap("error 1");
            };
            let ?indirect = coreModules.get("indirect") else {
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
                        initialIndirect = indirect;
                        packageManagerOrBootstrapper = backend;
                    }); // TODO: Add more arguments.
                    installationId;
                    packageManagerOrBootstrapper = backend;
                    initialIndirect = indirect;
                    preinstalledCanisterId = coreModules.get(packageName);
                    user; // TODO: `!`
                    wasmModule = Common.shareModule(m); // TODO: We unshared, then shared it, huh?
                });
                moduleNumber += 1;
            };
        }
        catch (e) {
            Debug.print("installPackageWrapper: " # Error.message(e));
        };
    };

    private type Callbacks = actor {
        onCreateCanister: shared ({
            installPackage: Bool;
            installationId: Common.InstallationId;
            moduleNumber: Nat;
            moduleName: ?Text;
            canister: Principal;
            user: Principal;
        }) -> async ();
        onInstallCode: shared ({
            installPackage: Bool;
            installationId: Common.InstallationId;
            moduleNumber: Nat;
            moduleName: ?Text;
            module_: Common.SharedModule;
            canister: Principal;
            user: Principal;
            packageManagerOrBootstrapper: Principal;
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
        preinstalledCanisterId: ?Principal;
        installArg: Blob;
    }): () {
        try {
            Debug.print("installModule" # debug_show(moduleName) # " preinstalled: " # debug_show(preinstalledCanisterId));

            onlyOwner(caller, "installModule");

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
                        user;
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
        installArg: Blob;
        user: Principal;
    }): async* Principal {
        // Later bootstrapper transfers control to the PM's `indirect_caller` and removes being controlled by bootstrapper.
        // FIXME:
        let {canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[packageManagerOrBootstrapper, user, initialIndirect];
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
        });

        canister_id;
    };
}