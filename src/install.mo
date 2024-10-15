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
    /// TODO: Rename this function.
    public func _installModuleButDontRegister({
        wasmModule: Common.Module;
        installArg: Blob;
        initArg: ?Blob; // init is optional
        indirectCaller: IndirectCaller.IndirectCaller;
        packageManagerOrBootstrapper: Principal;
        user: Principal;
        data: Blob;
        callback: ?(shared ({
            can: Principal;
            installationId: Common.InstallationId;
            indirectCaller: IndirectCaller.IndirectCaller; // TODO: Rename.
            packageManagerOrBootstrapper: Principal;
            data: Blob;
        }) -> async ());
    }): async* {installationId: Common.InstallationId} {
        Debug.print("_installModuleButDontRegister"); // FIXME: Remove.
        let pm = actor (Principal.toText(packageManagerOrBootstrapper)) : actor {
            createInstallation: () -> async Common.InstallationId;
        };
        let installationId = await pm.createInstallation();
        indirectCaller.installModuleButDontRegisterWrapper({
            installationId;
            wasmModule;
            installArg;
            initArg;
            packageManagerOrBootstrapper;
            user;
            callback;
            data;
        });
        {installationId};
    };

    public func _registerModule({
        installation: Common.InstallationId;
        canister: Principal;
        packageManager: Principal;
        // installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>; // FIXME
    }): async* () {
        // TODO:
        // let ?inst = installedPackages.get(installation) else {
        //     Debug.trap("no such installationId: " # debug_show(installation));
        // };
        // inst.allModules.add(canister);
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