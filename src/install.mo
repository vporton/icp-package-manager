import cycles_ledger "canister:cycles_ledger";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Sha256 "mo:sha2/Sha256";
import Settings "Settings";
import Common "common";
import CopyAssets "copy_assets";
import {ic} "mo:ic";
import Asset "mo:assets-api";

module {
    // TODO: (Here and in other places) rename `mainControllers`.
    public func myCreateCanister({mainControllers: ?[Principal]; user: Principal; cyclesAmount: Nat}): async* {canister_id: Principal} {
        let res = await cycles_ledger.create_canister({ // Owner is set later in `bootstrapBackend`.
            amount = cyclesAmount;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            creation_args = ?{
                settings = ?{
                    freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                    // TODO: Should we remove control from `user` to protect against errors?
                    controllers = mainControllers;
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

    public func myInstallCode({
        installationId: Common.InstallationId;
        canister_id: Principal;
        wasmModule: Common.Module;
        installArg: Blob;
        packageManagerOrBootstrapper: Principal;
        initialIndirect: Principal;
        simpleIndirect: Principal;
        user: Principal;
    }): async* () {
        let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
        let wasmModuleSourcePartition: Common.RepositoryPartitionRO = actor(Principal.toText(wasmModuleLocation.0));
        let ?(#blob wasm_module) =
            await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
        else {
            Debug.trap("package WASM code is not available");
        };

        Debug.print("Installing code for canister " # debug_show(canister_id));
        await ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({
                packageManagerOrBootstrapper;
                initialIndirect;
                simpleIndirect;
                user;
                installationId;
                userArg = installArg;
            });
            wasm_module;
            mode = #install;
            canister_id;
            sender_canister_version = null; // TODO
        });

        switch (wasmModule.code) {
            case (#Assets {assets}) {
                await* CopyAssets.copyAll({
                    from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                });
            };
            case _ {};
        };
    };
}