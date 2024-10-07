/// Common code for package manager and bootstrapper.
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Asset "mo:assets-api";
import copy_assets "copy_assets";
import Common "common";
import RepositoryPartition "repository_backend/RepositoryPartition";
import IndirectCaller "package_manager_backend/indirect_caller";

module {
    /// This is an internal function used in bootstrapper.
    ///
    /// Returns canister ID of installed module.
    ///
    /// TODO: Rename this function. // TODO: Make {} argument type.
    public func _installModuleButDontRegister(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManagerOrBootstrapper: Principal,
        user: Principal,
        frontend: ?Principal,
        repo: ?Common.RepositoryPartitionRO, // is some, only when callback is some
        callback: ?(shared ({
            can: Principal;
            indirect_caller_v: IndirectCaller.IndirectCaller;
            installationId: Common.InstallationId;
            repo: Common.RepositoryPartitionRO;
            frontend: Principal; // FIXME: hack!
        }) -> async ()),
    ): async* {installationId: Common.InstallationId; can: Principal} {
        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        Cycles.add<system>(10_000_000_000_000);
        // Later bootstrapper transfers control to the PM's `indirect_caller` and removes being controlled by bootstrapper.
        let {canister_id} = await IC.create_canister({ // Owner is set later in `bootstrapBackend`.
            settings = ?{
                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                controllers = ?[Principal.fromActor(indirectCaller), packageManagerOrBootstrapper];
                compute_allocation = null; // TODO
                memory_allocation = null; // TODO (a low priority task)
            }
        });
        let pm = actor(Principal.toText(canister_id)) : actor {
            createInstallation: shared () -> async (Common.InstallationId);
        };
        let installationId = await pm.createInstallation();
        
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
                        // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
                        canister = Principal.fromActor(IC);
                        name = "install_code";
                        data = to_candid({
                            arg = to_candid({
                                userArg = installArg;
                                packageManagerOrBootstrapper;
                                user;
                            });
                            wasm_module;
                            mode = #install;
                            canister_id;
                            // sender_canister_version = ;
                        });
                    },
                    {
                        canister = Principal.fromActor(indirectCaller);
                        name = "copyAll";
                        data = to_candid({
                            from = actor(Principal.toText(assets)): Asset.AssetCanister; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                        });
                    },
                    // TODO: Should here also call `init()` like below?
                ]);
            };
            case _ {
                indirectCaller.callIgnoringMissingOneWay([
                    {
                        canister = Principal.fromActor(IC);
                        name = "install_code";
                        data = to_candid({
                            arg = to_candid({
                                userArg = installArg;
                                packageManagerOrBootstrapper;
                                user;
                            });
                            wasm_module;
                            mode = #install;
                            canister_id;
                        });
                    },
                    {
                        canister = canister_id;
                        name = Common.NamespacePrefix # "init";
                        data = to_candid({
                            user;
                            packageManagerOrBootstrapper;
                            indirect_caller = Principal.fromActor(indirectCaller); // TODO: consistent casing
                            arg = initArg;
                        });
                    },
                ]);
            };
        };
        switch (callback) {
            case (?callback) {
                let ?fe2 = frontend else {
                    Debug.trap("programming error");
                };
                let ?r = repo else {
                    Debug.trap("programming error");
                };
                await callback({can = canister_id; indirect_caller_v = indirectCaller; installationId; frontend = fe2; repo = r}); // TODO: Rename variable.
            };
            case null {};
        };
        {installationId; can = canister_id};
    };

    public func _installModule(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManager: Principal,
        installation: Common.InstallationId,
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>, // TODO: not here
        user: Principal,
    ): async* Principal {
        let {can = canister} = await* _installModuleButDontRegister(wasmModule, installArg, initArg, indirectCaller, packageManager, user, null, null, null);
        await* _registerModule({installation; canister; packageManager; installedPackages});
        canister;
    };

    public func _installNamedModule(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManager: Principal,
        installation: Common.InstallationId,
        moduleName: Text,
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>, // TODO: not here
        user: Principal,
   ): async* Principal {
        let {can = canister} = await* _installModuleButDontRegister(wasmModule, installArg, initArg, indirectCaller, packageManager, user, null, null, null);
        await* _registerNamedModule({installation; canister; packageManager; moduleName; installedPackages});
        canister;
    };

    public func _registerModule({
        installation: Common.InstallationId;
        canister: Principal;
        packageManager: Principal;
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>; // TODO: not here
    }): async* () {
        let ?inst = installedPackages.get(installation) else {
            Debug.trap("no such installationId: " # debug_show(installation));
        };
        inst.allModules.add(canister);
        // TODO
    };

    public func _registerNamedModule({
        installation: Common.InstallationId;
        canister: Principal;
        packageManager: Principal;
        moduleName: Text;
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>; // TODO: not here
    }): async* () {
        await* _registerModule({installation; canister; packageManager; installedPackages});
        let ?inst = installedPackages.get(installation) else {
            Debug.trap("no such installationId: " # debug_show(installation));
        };
        inst.modules.put(moduleName, canister);
    };
}