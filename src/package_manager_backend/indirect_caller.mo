/// Canister that takes on itself potentially non-returning calls.
import Exp "mo:base/ExperimentalInternetComputer";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Asset "mo:assets-api";
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
    private func callAllOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        label cycle for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data); 
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
    /// FIXME: We don't need this function.
    private func callIgnoringMissingOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data);
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

    /// FIXME: We don't need this function.
    public shared({caller}) func callIgnoringMissingOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        await* callIgnoringMissingOneWayImpl(caller, methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        await* callAllOneWayImpl(caller, methods);
    };

    /// FIXME: We don't need this function.
    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        try {
            return await IC.call(method.canister, method.name, method.data); 
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
            return await IC.call(method.canister, method.name, method.data);
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
        repo: Common.RepositoryPartitionRO;
        pmPrincipal: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        installationId: Common.InstallationId;
        preinstalledModules: ?[(Text, Principal)];
    }): () {
        try {
            Debug.print("installPackageWrapper"); // TODO: Remove.

            onlyOwner(caller);

            let package = await repo.getPackage(packageName, version); // unsafe operation, run in indirect_caller

            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                installationWorkCallback: ({
                    installationId: Common.InstallationId;
                    // createdCanister: Principal; // FIXME: seems superfluous
                    caller: Principal;
                    package: Common.SharedPackageInfo;
                    indirectCaller: IndirectCaller;
                }) -> async ();
            };

            Debug.print("Call installationWorkCallback");
            await pm.installationWorkCallback({ // FIXME: This callback should call the next one, in order to deliver `createdCanister`.
                installationId;
                // createdCanister;
                caller;
                package;
                indirectCaller = this;
            });
        }
        catch (e) {
            Debug.print("installPackageWrapper: " # Error.message(e));
        };
    };

    private func _installModuleCode({
        installationId: Common.InstallationId;
        wasmModule: Common.Module;
    }): async* Principal {
        let IC: Common.CanisterCreator = actor("aaaaa-aa");
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
        let pm = actor(Principal.toText(packageManagerOrBootstrapper)) : actor { // FIXME: What we do, if it's bootstrapper?
            updateModule: shared () -> async (Common.InstallationId);
        };

        let wasmModuleLocation = switch (wasmModule.code) {
            case (#Wasm wasmModuleLocation) {
                wasmModuleLocation;
            };
            case (#Assets {wasm}) {
                wasm;
            };
        };
        let wasmModuleSourcePartition: Common.RepositoryPartitionRO = actor(Principal.toText(wasmModuleLocation.0));
        let ?(#blob wasm_module) =
            await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
        else {
            Debug.trap("package WASM code is not available");
        };

        switch (wasmModule.code) {
            case (#Assets {assets}) {
                await IC.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
                    arg = Blob.toArray(to_candid({
                        userArg = installArg;
                        packageManagerOrBootstrapper;
                        user;
                    }));
                    wasm_module;
                    mode = #install;
                    canister_id;
                    // sender_canister_version = ;
                });
                await this.copyAll({ // TODO: Don't call shared.
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
                // TODO: Should here also call `init()` like below?
            };
            case _ {
                let arg = {
                    userArg = installArg;
                    packageManagerOrBootstrapper;
                    user;
                };
                await IC.install_code({
                    arg = Blob.toArray(to_candid(arg));
                    wasm_module;
                    mode = #install;
                    canister_id;
                });
                // TODO:
                // modules = Iter.toArray(Iter.map<(Text, (Principal, {#empty; #installed})), (Text, Principal)>(
                //     ourHalfInstalled.modules.entries(),
                //     func ((x, (y, z)): (Text, (Principal, {#empty; #installed}))) = (x, y),
                // ));
            };
        };
        canister_id;
    };

    // FIXME: Accept `preinstalledModules`.
    public shared func installModule({
        installationId: ?Common.InstallationId; /// `null` means we are not installing a package.
        wasmModule: Common.Module;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        preinstalledCanisterId: ?Principal;
        weArePackageManager: Bool;
    }): () {
        try {
            // onlyOwner(caller); // FIXME: Uncomment.
            let canister_id = switch (preinstalledCanisterId) {
                case (?preinstalledCanisterId) preinstalledCanisterId;
                case (null) await* _installModuleCode({installationId; wasmModule});
            };
            let pmPrincipal = if (weArePackageManager) {
                canister_id;
            } else {
                packageManagerOrBootstrapper;
            };
            let pm = actor(pmPrincipal);
            pm.updateModule({installationId}); // FIXME: Add arguments.
        }
        catch (e) {
            let msg = "installModuleButDontRegisterWrapper: " # Error.message(e);
            Debug.print(msg);
        };
    };
}