import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Common "common";
import CopyAssets "copy_assets";
import {ic} "mo:ic";
import Asset "mo:assets-api";
import cmc "canister:cmc";

module {
    /// `cyclesAmount` is the total cycles amount, including canister creation fee.
    public func myCreateCanister({
        controllers: ?[Principal];
        cyclesAmount: Nat;
        subnet_selection: ?cmc.SubnetSelection;
    }): async* {canister_id: Principal} {
        Cycles.add<system>(cyclesAmount);
        let res = await cmc.create_canister({
            settings = ?{
                // TODO
                compute_allocation = null;
                controllers = controllers;
                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                log_visibility = null;
                memory_allocation = null; // TODO (a low priority task)
                reserved_cycles_limit = null;
                wasm_memory_limit = null;
                wasm_memory_threshold = null;
            };
            subnet_selection;
            subnet_type = null;
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
        let repository: Common.RepositoryRO = actor(Principal.toText(wasmModuleLocation.0)); // TODO: Rename.
        let wasm_module = await repository.getWasmModule(wasmModuleLocation.1);

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
                // TODO: duplicate work with bootstrapper
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

    public type Callbacks = actor {
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

    public func _installModuleCode({
        moduleNumber: Nat;
        moduleName: ?Text;
        installationId: Common.InstallationId;
        upgradeId: ?Common.UpgradeId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        installArg: Blob;
        user: Principal;
        controllers: ?[Principal];
        cyclesAmount: Nat;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async* Principal {
        let {canister_id} = await* myCreateCanister({
            controllers;
            cyclesAmount;
            subnet_selection = null;
        });
        await* _installModuleCodeOnly({
            moduleNumber;
            moduleName;
            installationId;
            upgradeId;
            wasmModule;
            packageManagerOrBootstrapper;
            mainIndirect;
            simpleIndirect;
            installArg;
            user;
            afterInstallCallback;
            canister_id: Principal;
        });
    };

    public func _installModuleCodeOnly({
        moduleNumber: Nat;
        moduleName: ?Text;
        installationId: Common.InstallationId;
        upgradeId: ?Common.UpgradeId;
        wasmModule: Common.Module;
        packageManagerOrBootstrapper: Principal;
        mainIndirect: Principal;
        simpleIndirect: Principal;
        installArg: Blob;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        canister_id: Principal;
    }): async* Principal {
        let pm: Callbacks = actor(Principal.toText(packageManagerOrBootstrapper));
    
        await* myInstallCode({
            installationId;
            upgradeId;
            canister_id;
            wasmModule;
            installArg;
            packageManagerOrBootstrapper;
            mainIndirect;
            simpleIndirect;
            user;
        });

        // Remove `mainIndirect` as a controller, because it's costly to replace it in every canister after new version of `mainIndirect`..
        // Note that packageManagerOrBootstrapper calls it on getMainIndirect(), not by itself, so doesn't freeze.
        await ic.update_settings({
            canister_id;
            sender_canister_version = null;
            settings = {
                compute_allocation = null;
                controllers = ?[simpleIndirect, user];
                freezing_threshold = null;
                log_visibility = null;
                memory_allocation = null;
                reserved_cycles_limit = null;
                wasm_memory_limit = null;
            };
        });

        await pm.onInstallCode({
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
}