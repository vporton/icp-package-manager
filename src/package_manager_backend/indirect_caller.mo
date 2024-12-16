/// Canister that takes on itself potentially non-returning calls.
// import Exp "mo:base/ExperimentalInternetComputer"; // TODO: This or ICE.call for calls?
import Cycles "mo:base/ExperimentalCycles";
import ICE "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Asset "mo:assets-api";
import IC "mo:ic";
import Sha256 "mo:sha2/Sha256";
import CanDb "mo:candb/CanDB";
import Settings "../Settings";
import Common "../common";
import CopyAssets "../copy_assets";
import cycles_ledger "canister:cycles_ledger";

shared({caller = initialCaller}) actor class IndirectCaller({
    packageManagerOrBootstrapper: Principal;
    initialIndirect: Principal; // TODO: Rename.
    userArg: Blob;
}) = this {
    let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
        installationId: Common.InstallationId; // FIXME: Can we remove this?
        user: Principal;
        initialOwner: Principal;
    } = from_candid(userArg) else {
        Debug.trap("argument userArg is wrong");
    };

    stable var initialized = false;

    public shared({caller}) func init({ // TODO
        installationId: Common.InstallationId;
        canister: Principal;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
    }): async () {
        onlyOwner(caller, "init");

        // FIXME:
        // owners.delete(initialCaller);
        // owners.delete(initialOwner);
        owners.put(initialCaller, ()); // self-usage to call `this.installModule`.
        owners.put(userArgValue.initialOwner, ()); // self-usage to call `this.installModule`.
        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`.
        owners.put(userArgValue.user, ());
        owners.put(packageManagerOrBootstrapper, ()); // This is `aaaaa-aa` in bootstrapping.
        ourPM := actor (Principal.toText(packageManagerOrBootstrapper)): OurPMType;
        initialized := true;
    };

    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
    };

    // stable var _ownersSave: [(Principal, ())] = []; // We don't ugrade this package
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            // FIXME
            // FIXME: Remove BootrapperIndirectCaller later.
            // FIXME: Reliance on BootrapperIndirectCaller in additional copies of package manager.
            [(userArgValue.initialOwner, ()), (userArgValue.user, ()), (packageManagerOrBootstrapper, ()), (initialIndirect, ())].vals(),
            4,
            Principal.equal,
            Principal.hash);

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

    /*stable*/ var ourPM: OurPMType = actor("aaaaa-aa");

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
            Debug.print("R1");
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

            // TODO: The following can't work during bootstrapping, because we are `BootstrapperIndirectCaller`. But bootstrapping succeeds.
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

            Debug.print("THIS " # debug_show([("backend", Principal.fromActor(ourPM)), ("indirect", Principal.fromActor(this))]));
            let bi = if (preinstalledModules.size() == 0) { // TODO: All this block is a crude hack.
                [("backend", Principal.fromActor(ourPM)), ("indirect", Principal.fromActor(this))];
            } else {
                preinstalledModules;
            };
            let coreModules = HashMap.fromIter<Text, Principal>(bi.vals(), bi.size(), Text.equal, Text.hash);
            var moduleNumber = 0;
            Debug.print("R2: " # debug_show(Iter.toArray(coreModules.entries())));
            let ?backend = coreModules.get("backend") else {
                Debug.trap("error 1");
            };
            Debug.print("R3");
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
                    installArg = to_candid({installationId; user; initialOwner = indirect; packageManagerOrBootstrapper = Principal.fromActor(ourPM)}); // FIXME // TODO: Add more arguments.
                    installationId;
                    packageManagerOrBootstrapper = backend; // TODO: Rename this argument. // FIXME
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
            module_: Common.SharedModule;
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
        }) -> async ();
    };

    private func myCreateCanister({packageManagerOrBootstrapper: Principal; user: Principal}): async* {canister_id: Principal} {
        // a workaround of calling getNewCanisterCycles() before setOurPM() // TODO: hack
        var amount = 600_000_000_000; // TODO
        if (Principal.fromActor(ourPM) != Principal.fromText("aaaaa-aa")) {
            amount := await ourPM.getNewCanisterCycles();
        };
        // Cycles.add<system>(await ourPM.getNewCanisterCycles());
        let res = await cycles_ledger.create_canister({ // Owner is set later in `bootstrapBackend`.
            amount;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            creation_args = ?{
                settings = ?{
                    freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                    controllers = ?[Principal.fromActor(this), packageManagerOrBootstrapper]; // TODO: Needs to be self-invokable?
                    compute_allocation = null; // TODO
                    memory_allocation = null; // TODO (a low priority task)
                };
                subnet_selection = null;
            };
            from_subaccount = if (Settings.debugFunds) {
                null;
            } else {
                ?Blob.toArray(Sha256.fromBlob(#sha256, to_candid(user))); // TODO: not the most efficient way (but is it standard?)
            };
        });
        let canister_id = switch (res) {
            case (#Ok {canister_id}) canister_id;
            case (#Err err) {
                let msg = debug_show(err);
                Debug.print("cannot create canister: " # msg);
                Debug.trap("cannot create canister: " # msg);
            };  
        };
        {canister_id};
    };

    private func myInstallCode({
        canister_id: Principal;
        wasmModule: Common.Module;
        installArg: Blob;
        packageManagerOrBootstrapper: Principal;
        initialIndirect: Principal;
        user: Principal;
    }): async* () {
        let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
        let wasmModuleSourcePartition: Common.RepositoryPartitionRO = actor(Principal.toText(wasmModuleLocation.0));
        let ?(#blob wasm_module) =
            await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
        else {
            Debug.trap("package WASM code is not available");
        };

        await IC.ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({
                packageManagerOrBootstrapper;
                initialIndirect;
                user;
                userArg = installArg;
            });
            wasm_module;
            mode = #install;
            canister_id;
            sender_canister_version = null; // TODO
        });

        switch (wasmModule.code) {
            case (#Assets {assets}) {
                await* CopyAssets.copyAll({ // TODO: Don't call shared.
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
            };
            case _ {};
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
        Debug.print("C1");
        // Later bootstrapper transfers control to the PM's `indirect_caller` and removes being controlled by bootstrapper.
        let {canister_id} = await* myCreateCanister({packageManagerOrBootstrapper; user; initialIndirect});
        Debug.print("C2");

        let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
        Debug.print("C3");
        await pm.onCreateCanister({
            installPackage; // Bool
            moduleNumber;
            moduleName;
            module_ = Common.shareModule(wasmModule);
            installationId;
            canister = canister_id;
            user;
        });
        Debug.print("C4");

        await* myInstallCode({
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
        });

        canister_id;
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
            Debug.print("D1");
            onlyOwner(caller, "installModule");

            switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) {
                    let cb: Callbacks = actor (Principal.toText(packageManagerOrBootstrapper));
                    await cb.onCreateCanister({
                        installPackage;
                        installationId;
                        moduleNumber;
                        moduleName;
                        module_ = wasmModule;
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
                    });
                };
                case null {
                    Debug.print("D2");
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
                    Debug.print("D3");
                };
            };
        }
        catch (e) {
            let msg = "installModule: " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        initialIndirect: Principal;
    }): async {canister_id: Principal} {
        let {canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = Principal.fromActor(this); user}); // TODO: This is a bug.
        await* myInstallCode({
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // TODO: This is a bug.
            initialIndirect;
            user;
        });
        {canister_id};
    };

    public shared func bootstrapBackend({
        frontend: Principal;
        backendWasmModule: Common.SharedModule;
        indirectWasmModule: Common.SharedModule;
        user: Principal;
        repo: Common.RepositoryPartitionRO;
        packageManagerOrBootstrapper: Principal;
    }): async {backendPrincipal: Principal; indirectPrincipal: Principal} {
        // TODO: Create and run two canisters in parallel.
        let {canister_id = backend_canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = Principal.fromActor(this); user}); // TODO: This is a bug.
        let {canister_id = indirect_canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = backend_canister_id; user}); // TODO: This is a bug.

        await* myInstallCode({
            canister_id = backend_canister_id;
            wasmModule = Common.unshareModule(backendWasmModule);
            installArg = to_candid({
                user;
                installationId = 0; // TODO
                initialOwner = indirect_canister_id; // FIXME: Correct?
                packageManagerOrBootstrapper = Principal.fromActor(ourPM);
            });
            packageManagerOrBootstrapper;
            initialIndirect = indirect_canister_id;
            user;
        });

        await* myInstallCode({
            canister_id = indirect_canister_id;
            wasmModule = Common.unshareModule(indirectWasmModule);
            installArg = to_candid({
                user;
                installationId = 0; // TODO
                initialOwner = indirect_canister_id; // FIXME: Correct?
                packageManagerOrBootstrapper = Principal.fromActor(ourPM); // FIXME: All code with `packageManagerOrBootstrapper = ` is a hack.
            });
            packageManagerOrBootstrapper = backend_canister_id;
            initialIndirect;
            user;
        });

        // let _indirect = actor (Principal.toText(indirect_canister_id)) : actor {
        //     addOwner: (newOwner: Principal) -> async ();
        //     setOurPM: (pm: Principal) -> async ();
        //     removeOwner: (oldOwner: Principal) -> async (); 
        // };

        // let _backend = actor (Principal.toText(backend_canister_id)) : actor {
        //     // setOwners: (newOwners: [Principal]) -> async ();
        //     setIndirectCaller: (indirect_caller: IndirectCaller) -> async (); 
        //     addOwner: (newOwner: Principal) -> async (); 
        //     removeOwner: (oldOwner: Principal) -> async (); 
        // };

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id};
    };
}