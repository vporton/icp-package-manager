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
import Asset "mo:assets-api";
import IC "mo:ic";
import Common "../common";
import CopyAssets "../copy_assets";
import cycles_ledger "canister:cycles_ledger";

shared({caller = initialOwner}) actor class IndirectCaller() = this {
    stable var owner = initialOwner;

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal, msg: Text) {
        if (caller != owner and caller != Principal.fromActor(this)) { // TODO: Comparison with this is necessary for call of `copyAssets` from `callAllOneWay`.
            Debug.trap("not the owner: " # msg);
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal): async () {
        onlyOwner(caller, "setOwner");

        owner := newOwner;
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

    public shared({caller}) func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async () {
        onlyOwner(caller, "copyAll");

        try {
            return await* CopyAssets.copyAll({from; to});
        }
        catch (e) {
            Debug.print("Indirect caller copyAll: " # Error.message(e));
            Debug.trap("Indirect caller copyAll: " # Error.message(e));
        };
    };

    public shared({caller}) func installPackageWrapper({ // TODO: Rename.
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        repo: Common.RepositoryPartitionRO;
        pmPrincipal: ?Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        installationId: Common.InstallationId;
        preinstalledModules: [(Text, Principal)];
        user: Principal;
    }): () {
        try {
            Debug.print("installPackageWrapper"); // FIXME: Remove.
            // onlyOwner(caller, "installPackageWrapper"); // FIXME: Uncomment.
            Debug.print("Y1"); // FIXME: Remove.

            let package = await repo.getPackage(packageName, version); // unsafe operation, run in indirect_caller
            Debug.print("Y2"); // FIXME: Remove.

            let realPMPrincipal = switch (pmPrincipal) {
                case (?pmPrincipal) {
                    pmPrincipal;
                };
                case null {
                    preinstalledModules[0].1;
                };
            };
            Debug.print("Y3"); // FIXME: Remove.
            let pm = actor (Principal.toText(realPMPrincipal)) : actor {
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

            await pm.installationWorkCallback({ // FIXME: We have no permission in `pm` because we are `BootstrapperIndirectCaller`.
                whatToInstall; /// install package or named modules.
                installationId;
                user;
                package;
                repo;
                preinstalledModules;
            });
            Debug.print("D"); // FIXME: Remove.
        }
        catch (e) {
            Debug.print("installPackageWrapper: " # Error.message(e));
        };
    };

    private type Callbacks = actor {
        onCreateCanister: shared ({
            installPackage: Bool;
            installationId: Common.InstallationId;
            canister: Principal;
            user: Principal;
        }) -> async ();
        onInstallCode: shared ({
            installPackage: Bool;
            installationId: Common.InstallationId;
            user: Principal;
        }) -> async ();
    };

    private func myCreateCanister({packageManagerOrBootstrapper: Principal}): async* {canister_id: Principal} {
        let res = await cycles_ledger.create_canister({ // Owner is set later in `bootstrapBackend`.
            amount = 10_000_000_000_000; // FIXME
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            creation_args = ?{
                settings = ?{
                    freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                    controllers = ?[Principal.fromActor(this), packageManagerOrBootstrapper];
                    compute_allocation = null; // TODO
                    memory_allocation = null; // TODO (a low priority task)
                };
                subnet_selection = null;
            };
            from_subaccount = null; // FIXME
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
                await this.copyAll({ // TODO: Don't call shared.
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
            };
            case _ {};
        };
    };

    private func _installModuleCode({
        moduleName: ?Text;
        installPackage: Bool;
        installationId: Common.InstallationId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        installArg: Blob;
        user: Principal;
        noPMBackendYet: Bool; // Don't call callbacks
    }): async* Principal {
        Debug.print("_installModuleCode"); // FIXME: Remove.
        Cycles.add<system>(10_000_000_000_000);
        // Later bootstrapper transfers control to the PM's `indirect_caller` and removes being controlled by bootstrapper.
        let {canister_id} = await* myCreateCanister({packageManagerOrBootstrapper});
        if (not noPMBackendYet) {
            let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
            await pm.onCreateCanister({
                installPackage; // Bool
                moduleName;
                module_ = Common.shareModule(wasmModule);
                installationId;
                canister = canister_id;
                user;
            });
        };

        await* myInstallCode({
            canister_id;
            wasmModule;
            installArg;
            packageManagerOrBootstrapper;
            user;
        });
        if (not noPMBackendYet) {
            let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
            await pm.onInstallCode({
                installPackage; // Bool
                moduleName;
                module_ = Common.shareModule(wasmModule);
                canister = canister_id;
                installationId;
                user;
            });
        };
        canister_id;
    };

    // TODO: I have several arguments indicating bootstrap: noPMBackendYet, preinstalledCanisterId.
    public shared func installModule({
        installPackage: Bool;
        installationId: Common.InstallationId;
        moduleName: ?Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        preinstalledCanisterId: ?Principal;
        installArg: Blob;
        noPMBackendYet: Bool; // TODO: used?
    }): () {
        try {
            // onlyOwner(caller, "installModule"); // FIXME: Uncomment.

            switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) {
                    if (not noPMBackendYet) {
                        let packageManagerOrBootstrapper: Callbacks = actor (Principal.toText(preinstalledCanisterId));
                        Debug.print("A1");
                        await packageManagerOrBootstrapper.onCreateCanister({
                            installPackage;
                            installationId;
                            moduleName;
                            canister = preinstalledCanisterId;
                            user;
                        });
                        Debug.print("A2");
                        await packageManagerOrBootstrapper.onInstallCode({
                            installPackage;
                            installationId;
                            canister = preinstalledCanisterId;
                            user;
                        });
                        Debug.print("A3");
                    }
                };
                case null {
                    Debug.print("B1");
                    ignore await* _installModuleCode({
                        installationId;
                        moduleName;
                        wasmModule = Common.unshareModule(wasmModule);
                        installPackage;
                        installArg;
                        packageManagerOrBootstrapper;
                        user;
                        noPMBackendYet;
                    });
                    Debug.print("B2");
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
    }): async {canister_id: Principal} {
        let {canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = Principal.fromActor(this)}); // TODO: This is a bug.
        await* myInstallCode({
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // TODO: This is a bug.
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
        Debug.print("bootstrapBackend"); // FIXME: Remove.
        // TODO: Create and run two canisters in parallel.
        let {canister_id = backend_canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = Principal.fromActor(this)}); // TODO: This is a bug.
        let {canister_id = indirect_canister_id} = await* myCreateCanister({packageManagerOrBootstrapper = Principal.fromActor(this)}); // TODO: This is a bug.

        Debug.print("Z1"); // FIXME: Remove.
        await* myInstallCode({
            canister_id = backend_canister_id;
            wasmModule = Common.unshareModule(backendWasmModule);
            installArg = to_candid({
                initialIndirectCaller = indirect_canister_id;
            });
            packageManagerOrBootstrapper;
            user;
        });
        Debug.print("Z2"); // FIXME: Remove.

        Debug.print("Z3"); // FIXME: Remove.
        await* myInstallCode({
            canister_id = indirect_canister_id;
            wasmModule = Common.unshareModule(indirectWasmModule);
            installArg = to_candid({});
            packageManagerOrBootstrapper = Principal.fromActor(this); // TODO: This is a bug.
            user;
        });
        Debug.print("Z4"); // FIXME: Remove.

        // TODO: Make init() functions conforming to the specs and call init() automatically.
        let backend = actor(Principal.toText(backend_canister_id)): actor {
            installPackageWithPreinstalledModules: shared ({
                whatToInstall: {
                    #package;
                    #simplyModules : [(Text, Common.SharedModule)];
                };
                packageName: Common.PackageName;
                version: Common.Version;
                preinstalledModules: [(Text, Principal)];
                repo: Common.RepositoryPartitionRO;
                user: Principal;
                indirectCaller: Principal;
            }) -> async {installationId: Common.InstallationId};
            init: shared ({user: Principal; indirect_caller: Principal}) -> async ();
            removeOwner: shared (oldOwner: Principal) -> async ();
        };
        Debug.print("Z5"); // FIXME: Remove.
        let indirect = actor(Principal.toText(indirect_canister_id)): actor {
            setOwner: shared (newOwner: Principal) -> async ();
        };
        Debug.print("Z6"); // FIXME: Remove.
        // ignore await backend.installPackageWithPreinstalledModules({
        //     whatToInstall = #package;
        //     packageName = "icpack";
        //     version = "0.0.1"; // TODO: should be `stable`.
        //     preinstalledModules = [("frontend", frontend), ("backend", backend_canister_id), ("indirect", indirect_canister_id)];
        //     repo;
        //     user;
        //     indirectCaller = indirect_canister_id;
        // });
        // await backend.init({user; indirect_caller = indirect_canister_id});
        // await indirect.setOwner(backend_canister_id);
        // await backend.removeOwner(Principal.fromActor(this));

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id};
    };
}