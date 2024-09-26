/// Common code for package manager and bootstrapper.
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Asset "mo:assets-api";
import copy_assets "copy_assets";
import Common "common";
import RepositoryPartition "repository_backend/RepositoryPartition";
import IndirectCaller "package_manager_backend/indirect_caller";

module {
    /// TODO: Save module info for such things as uninstallation and cycles management.
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

        Cycles.add<system>(10_000_000_000_000);
        // FIXME: Later transfer control to the PM's indirect_caller.
        let {canister_id} = await IC.create_canister({
            settings = ?{
                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                controllers = null; // FIXME: ?[Principal.fromActor(indirectCaller)]; // No package manager as a controller, because the PM may be upgraded.
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

        Debug.print("indirect_caller: " # Principal.toText(Principal.fromActor(indirectCaller))); // TODO: Remove.

        switch (wasmModule) {
            case (#Assets {assets}) {
                // FIXME: Remove:
                    await IC.install_code({
                            // user = ; // TODO: Useful? Maybe, just ask PM?
                            packageManager;
                            arg = Blob.toArray(installArg);
                            wasm_module;
                            mode = #install;
                            canister_id;
                        });
                    await* copy_assets.copyAll({
                            from = actor(Principal.toText(assets)); to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                        });
                // FIXME: Uncomment:
                // indirectCaller.callAllOneWay([
                //     {
                //         canister = Principal.fromActor(IC);
                //         name = "install_code";
                //         data = to_candid({
                //             // user = ; // TODO: Useful? Maybe, just ask PM?
                //             packageManager;
                //             arg = Blob.toArray(installArg);
                //             wasm_module;
                //             mode = #install;
                //             canister_id;
                //         });
                //     },
                //     // TODO: Two following operations could run in parallel.
                //     // FIXME: These `grant_permissions` fail:
                //     {
                //         canister = canister_id;
                //         name = "grant_permission";
                //         data = to_candid({
                //             to_principal = indirectCaller;
                //             permission = #Prepare;
                //         });
                //     },
                //     {
                //         canister = canister_id;
                //         name = "grant_permission";
                //         data = to_candid({
                //             to_principal = indirectCaller;
                //             permission = #Commit;
                //         });
                //     },
                //     {
                //         canister = Principal.fromActor(indirectCaller);
                //         name = "copyAll";
                //         data = to_candid({
                //             from = assets; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                //         });
                //     },
                //     // TODO: Should here also call `init()` like below?
                // ]);
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
                                name = Common.NamespacePrefix # "init";
                                data = to_candid({
                                    // user = ; // TODO: Useful? Maybe, just ask PM?
                                    packageManager;
                                    arg = {indirect_caller = indirectCaller; arg = initArg};
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