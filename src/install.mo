import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Common "common";
import CopyAssets "copy_assets";
import {ic} "mo:ic";
import Asset "mo:assets-api";
import cycles_ledger "canister:cycles_ledger";
import cmc "canister:cmc";

module {
    // TODO: (Here and in other places) rename `mainControllers`.
    public func myCreateCanister({mainControllers: ?[Principal]; user: Principal; cyclesAmount: Nat}): async* {canister_id: Principal} {
        let res = await cmc.create_canister({
            settings = ?{
                // TODO
                compute_allocation = null;
                controllers = mainControllers;
                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                log_visibility = null;
                memory_allocation = null; // TODO (a low priority task)
                reserved_cycles_limit = null;
                wasm_memory_limit = null;
                wasm_memory_threshold = null;
            };
            subnet_selection = null; // TODO
            subnet_type = null; // TODO
        });
        let canister_id = switch (res) {
            case (#Ok canister_id) canister_id;
            case (#Err err) {
                let msg = debug_show(err);
                Debug.print("cannot create canister: " # msg);
                Debug.trap("cannot create canister: " # msg);
            };  
        };
        {canister_id};
    };

    public func myInstallCode({
        installationId: Common.InstallationId;
        upgradeId: ?Common.UpgradeId;
        canister_id: Principal;
        wasmModule: Common.Module;
        installArg: Blob;
        packageManagerOrBootstrapper: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        user: Principal;
    }): async* () {
        let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
        let wasmModuleSourcePartition: Common.RepositoryRO = actor(Principal.toText(wasmModuleLocation.0)); // TODO: Rename.
        let wasm_module = await wasmModuleSourcePartition.getWasmModule(wasmModuleLocation.1);

        Debug.print("Installing code for canister " # debug_show(canister_id));
        await ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({
                packageManagerOrBootstrapper;
                mainIndirect;
                simpleIndirect;
                user;
                installationId;
                upgradeId;
                userArg = installArg;
            });
            wasm_module;
            mode = #install;
            canister_id;
            sender_canister_version = null; // TODO
        });

        await* copyAssetsIfAny({
            wasmModule;
            canister_id;
            simpleIndirect;
            user;
        });
    };

    public func copyAssetsIfAny({
        wasmModule: Common.Module;
        canister_id: Principal;
        simpleIndirect: Principal;
        user: Principal;
    }): async* () {
        switch (wasmModule.code) {
            case (#Assets {assets}) {
                Debug.print("Copy assets " # debug_show(assets) # " -> " # debug_show(canister_id));
                await* CopyAssets.copyAll({
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
                let assets2: Asset.AssetCanister = actor(Principal.toText(canister_id)); // TODO: Rename.
                let oldController = (await assets2.list_authorized())[0];
                for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
                    for (principal in [simpleIndirect, user].vals()) {
                        await assets2.grant_permission({to_principal = principal; permission});
                    };
                    await assets2.revoke_permission({
                        of_principal = oldController;
                        permission;
                    });
                };
            };
            case _ {};
        };
    };
}