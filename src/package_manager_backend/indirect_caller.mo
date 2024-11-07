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
import {ic} "mo:ic";
import Common "../common";
import CopyAssets "../copy_assets";
import cycles_ledger "canister:cycles_ledger";

shared({caller = initialOwner}) actor class IndirectCaller() = this {
    stable var owner = initialOwner;

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal) {
        if (caller != owner and caller != Principal.fromActor(this)) { // TODO: Comparison with this is necessary for call of `copyAssets` from `callAllOneWay`.
            Debug.print("only owner");
            Debug.trap("only owner");
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal): async () {
        onlyOwner(caller);

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
        onlyOwner(caller);

        await* callIgnoringMissingOneWayImpl(methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        await* callAllOneWayImpl(methods);
    };

    /// TODO: We don't need this function.
    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

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
        onlyOwner(caller);

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
        onlyOwner(caller);

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
            #bootstrap : [(Text, Principal)];
        };
        repo: Common.RepositoryPartitionRO;
        pmPrincipal: ?Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        installationId: Common.InstallationId;
        preinstalledModules: [(Text, Principal)];
        user: Principal;
        bootstrappingPM: Bool;
    }): () {
        try {
            Debug.print("installPackageWrapper"); // TODO: Remove.

            onlyOwner(caller);

            let package = await repo.getPackage(packageName, version); // unsafe operation, run in indirect_caller

            let realPMPrincipal = switch (pmPrincipal) {
                case (?pmPrincipal) {
                    pmPrincipal;
                };
                case null {
                    preinstalledModules[0].1;
                };
            };
            let pm = actor (Principal.toText(realPMPrincipal)) : actor {
                installationWorkCallback: ({
                    whatToInstall: {
                        #package;
                        #simplyModules : [(Text, Common.SharedModule)];
                        #bootstrap : [(Text, Principal)];
                    };
                    installationId: Common.InstallationId;
                    user: Principal;
                    package: Common.SharedPackageInfo;
                    repo: Common.RepositoryPartitionRO;
                    preinstalledModules: [(Text, Principal)];
                    bootstrappingPM: Bool;
                }) -> async ();
            };

            await pm.installationWorkCallback({
                whatToInstall; /// install package or named modules.
                installationId;
                user;
                package;
                repo;
                preinstalledModules;
                bootstrappingPM;
            });
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

    private func _installModuleCode({
        moduleName: ?Text;
        installPackage: Bool;
        installationId: Common.InstallationId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        installArg: Blob;
        user: Principal;
        bootstrappingPM: Bool; // We are installing the package manager.
    }): async* Principal {
        Cycles.add<system>(10_000_000_000_000);
        // Later bootstrapper transfers control to the PM's `indirect_caller` and removes being controlled by bootstrapper.
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
        let pmPrincipal = if (bootstrappingPM) {
            canister_id;
        } else {
            packageManagerOrBootstrapper;
        };
        if (not bootstrappingPM) {
            let pm: Callbacks = actor(Principal.toText(pmPrincipal));
            await pm.onCreateCanister({
                installPackage; // Bool
                moduleName;
                module_ = Common.shareModule(wasmModule);
                installationId;
                canister = canister_id;
                user;
            });
        };

        let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
        let wasmModuleSourcePartition: Common.RepositoryPartitionRO = actor(Principal.toText(wasmModuleLocation.0));
        let ?(#blob wasm_module) =
            await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
        else {
            Debug.trap("package WASM code is not available");
        };

        await ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({
                userArg = installArg;
                packageManagerOrBootstrapper;
                user;
            });
            wasm_module;
            mode = #install;
            canister_id;
            sender_canister_version = null; // TODO
        });
        if (not bootstrappingPM) {
            let pm: Callbacks = actor(Principal.toText(pmPrincipal));
            await pm.onInstallCode({
                installPackage; // Bool
                moduleName;
                module_ = Common.shareModule(wasmModule);
                canister = canister_id;
                installationId;
                user;
            });
        };
        switch (wasmModule.code) {
            case (#Assets {assets}) {
                await this.copyAll({ // TODO: Don't call shared.
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
            };
            case _ {};
        };
        canister_id;
    };

    // TODO: I have several arguments indicating bootstrap: bootstrappingPM, additionalArgs, preinstalledCanisterId.
    public shared func installModule({
        installPackage: Bool;
        installationId: Common.InstallationId;
        moduleName: ?Text;
        wasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        preinstalledCanisterId: ?Principal;
        installArg: Blob;
        bootstrappingPM: Bool; // FIXME: Here and in other places use `#bootstrap` instead.
        additionalArgs: {
            #bootstrap : [(Text, Principal)];
            #regular;
        }
    }): async Principal { // FIXME: Should be `()`.
        try {
            // onlyOwner(caller); // FIXME: Uncomment.

            let canister = switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) {
                    let preinstalledCanister: Callbacks = actor (Principal.toText(preinstalledCanisterId));
                    await preinstalledCanister.onCreateCanister({
                        installPackage;
                        installationId;
                        moduleName;
                        canister = preinstalledCanisterId;
                        user;
                    });
                    await preinstalledCanister.onInstallCode({
                        installPackage;
                        installationId;
                        canister = preinstalledCanisterId;
                        user;
                    });
                    preinstalledCanisterId;
                };
                case null {
                    await* _installModuleCode({
                        installationId;
                        moduleName;
                        wasmModule = Common.unshareModule(wasmModule);
                        installPackage;
                        installArg;
                        packageManagerOrBootstrapper;
                        user;
                        bootstrappingPM;
                    });
                };
            };
            switch (additionalArgs) {
                case (#bootstrap modules) {
                    // FIXME: Should be here only for installing `"backend"`, not frontend
                    let pm = actor(Principal.toText(modules[0].1)) : actor { // TODO: hardcoded module index
                        installPackageWithPreinstalledModules: shared ({
                            whatToInstall: {
                                #package;
                                #simplyModules : [(Text, Common.SharedModule)];
                                #bootstrap : [(Text, Principal)];
                            };
                            packageName: Common.PackageName;
                            version: Common.Version;
                            preinstalledModules: [(Text, Principal)];
                            repo: Common.RepositoryPartitionRO;
                            user: Principal;
                        }) -> async {installationId: Common.InstallationId};
                    };
                    ignore await pm.installPackageWithPreinstalledModules({
                        whatToInstall = #package;
                        packageName = "icpack"; // TODO: hack
                        version = "0.0.1"; // FIXME: bad hack
                        preinstalledModules = modules;
                        repo = actor("aaaaa-aa"); // hack
                        user;
                    });
                };
                case (#regular) {};
            };
            canister;
        }
        catch (e) {
            let msg = "installModule: " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };
}