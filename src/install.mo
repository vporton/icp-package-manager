/// Common code for package manager and bootstrapper.
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Asset "mo:assets-api";
import Common "common";
import RepositoryPartition "repository_backend/RepositoryPartition";
import IndirectCaller "package_manager_backend/indirect_caller";

module {
    /// TODO: Save module info for such things as uninstallation and cycles management.
    /// FIXME: But it should not saved on bootstrapping.
    ///
    /// Returns canister ID of installed module.
    public func _installModule(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManager: ?Principal, // may be null, if called from bootstrap.
    ): async* Principal {
        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        Cycles.add<system>(10_000_000_000_000); // TODO
        let {canister_id} = await IC.create_canister({
            settings = ?{
                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                controllers = ?[Principal.fromActor(indirectCaller)]; // No package manager as a controller, because the PM may be upgraded.
                compute_allocation = null; // TODO
                memory_allocation = null; // TODO (a low priority task)
            }
        });
        let wasmModuleLocation = switch (wasmModule) {
            case (#Wasm wasmModuleLocation) {
                wasmModuleLocation;
            };
            case (#Assets {wasm}) {
                wasm;
            };
        };
        let wasmModuleSourcePartition: RepositoryPartition.RepositoryPartition =
            actor(Principal.toText(wasmModuleLocation.0));
        let ?(#blob wasm_module) =
            await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
        else {
            Debug.trap("package WASM code is not available");
        };
        switch (wasmModule) {
            case (#Assets {assets}) {
                indirectCaller.callAllOneWay([
                    {
                        canister = Principal.fromActor(IC);
                        name = "install_code";
                        data = to_candid({
                            // user = ; // TODO: Useful? Maybe, just ask PM?
                            packageManager;
                            arg = Blob.toArray(installArg);
                            wasm_module;
                            mode = #install;
                            canister_id;
                        });
                    },
                    {
                        canister = Principal.fromActor(indirectCaller);
                        name = "copyAssetsCallback"; // FIXME: no such func
                        data = to_candid({
                            from = assets; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                        });
                    },
                    // TODO: Should here also call `init()` like below?
                ]);
            };
            case _ {
                let installCode = {
                    canister = Principal.fromActor(IC);
                    name = "install_code";
                    data = to_candid({
                        arg = Blob.toArray(installArg);
                        wasm_module;
                        mode = #install;
                        canister_id;
                    });
                };
                ignore await indirectCaller.call(installCode);
                switch (initArg) {
                    case (?initArg) {
                        indirectCaller.callIgnoringMissingOneWay([
                            {
                                canister = canister_id;
                                name = "init"; // FIXME: prefix?
                                data = to_candid({
                                    // user = ; // TODO: Useful? Maybe, just ask PM?
                                    packageManager;
                                    arg = {indirect_caller = indirectCaller};
                                });
                            }
                        ]);
                    };
                    case null {};
                };
            };
        };
        canister_id;
    };
}