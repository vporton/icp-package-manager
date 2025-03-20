/// This module is legible to non-returning-function attack. Throw it away if it fails this way.
/// Data is stored in `bootstrapper_data` instead.
import Asset "mo:assets-api";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";
import Data "canister:bootstrapper_data";
import Repository "canister:repository";

actor class Bootstrapper() = this {
    stable var newCanisterCycles = 600_000_000_000; // TODO: Edit it. (Move to `bootstrapper_data`?)

    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    public shared func bootstrapFrontend({
        installArg: Blob;
        user: Principal;
        frontendTweakPubKey: PubKey;
    }): async {canister_id: Principal} {
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );
        let ?wasmModule = modulesToInstall.get("frontend") else {
            Debug.trap("frontend module not found");
        };
        let {canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this)];
            user;
            cyclesAmount = newCanisterCycles;
        });
        await* Install.myInstallCode({
            installationId = 0;
            upgradeId = null;
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // modified by frontend tweak below.
            // Automated tests esnure that these `aaaaa-aa` don't appear at a later installation stage:
            mainIndirect = Principal.fromText("aaaaa-aa");
            simpleIndirect = Principal.fromText("aaaaa-aa");
            user;
        });
        await Data.putFrontendTweaker(canister_id, frontendTweakPubKey);
        {canister_id};
    };

    /// Installs the backend after frontend is already installed, tweaks frontend.
    ///
    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    public shared func bootstrapBackend({
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        frontend: Principal;
        frontendTweakPrivKey: PrivKey;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async {
        installedModules: [(Text, Principal)];
    } {
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        // Do a deep copy:
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );
        modulesToInstall.delete("frontend"); // We bootstrap backend at this stage.
        await* bootstrapBackendImpl({
            modulesToInstall;
            user;
            packageManagerOrBootstrapper;
            frontend;
            frontendTweakPrivKey;
            // repo;
            additionalPackages;
        });
    };

    private func bootstrapBackendImpl({
        modulesToInstall: HashMap.HashMap<Text, Common.SharedModule>;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        frontend: Principal;
        frontendTweakPrivKey: PrivKey;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async* {
        installedModules: [(Text, Principal)];
    } {
        // FIXME: At the beginning test that the user paid enough cycles.
        let installedModules = HashMap.HashMap<Text, Principal>(modulesToInstall.size(), Text.equal, Text.hash);
        for (moduleName in modulesToInstall.keys()) {
            let {canister_id} = await* Install.myCreateCanister({
                mainControllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
                user;
                cyclesAmount = newCanisterCycles;
            });
            installedModules.put(moduleName, canister_id);
        };
        let ?backend = installedModules.get("backend") else {
            Debug.trap("module not deployed");
        };
        let ?mainIndirect = installedModules.get("indirect") else {
            Debug.trap("module not deployed");
        };
        let ?simpleIndirect = installedModules.get("simple_indirect") else {
            Debug.trap("module not deployed");
        };
        for ((moduleName, canister_id) in installedModules.entries()) {
            let ?m = modulesToInstall.get(moduleName) else {
                Debug.trap("module not found");
            };
            // TODO: I specify `mainIndirect` two times.
            await* Install.myInstallCode({
                installationId = 0;
                upgradeId = null;
                canister_id;
                wasmModule = Common.unshareModule(m);
                installArg = to_candid({});
                packageManagerOrBootstrapper = if (moduleName == "backend") {
                    packageManagerOrBootstrapper // to call `installPackageWithPreinstalledModules` below
                } else {
                    backend
                };
                mainIndirect;
                simpleIndirect;
                user;
                // TODO: Pass the following only to the `backend` module:
                // frontend;
                // frontendTweakPrivKey;
                // repo = Repository;
                // additionalPackages;
            });
        };

        let controllers = [simpleIndirect, mainIndirect, backend, user];
        await* tweakFrontend(frontend, frontendTweakPrivKey, controllers);

        for (canister_id in installedModules.vals()) { // including frontend
            // TODO: We can provide these setting initially and thus update just one canister.
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // `indirect_canister_id` here is only for the package manager package:
                    controllers = ?controllers;
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

        let backendActor = actor(Principal.toText(backend)): actor {
            installPackageWithPreinstalledModules: shared ({
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryRO; 
                user: Principal;
                mainIndirect: Principal;
                /// Additional packages to install after bootstrapping.
                additionalPackages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryRO;
                }];
                preinstalledModules: [(Text, Principal)];
            }) -> async {minInstallationId: Common.InstallationId};
        };
        // TODO: Transfer user cycles before this call:
        ignore await backendActor.installPackageWithPreinstalledModules({
          whatToInstall = #package;
          packageName = "icpack";
          version = "0.0.1"; // TODO: should be `stable`.
          preinstalledModules = Iter.toArray(installedModules.entries());
          repo = Repository;
          user;
          mainIndirect;
          additionalPackages;
        });

        { installedModules = Iter.toArray(installedModules.entries()); }
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Internal. Updates controllers and owners of the frontend.
    private func tweakFrontend(
        frontend: Principal,
        privKey: PrivKey,
        controllers: [Principal],
    ): async* () {
        let pubKey = await Data.getFrontendTweaker(frontend);
        if (Sha256.fromBlob(#sha256, privKey) != pubKey) {
            Debug.trap("access denied");
        };
        let assets: Asset.AssetCanister = actor(Principal.toText(frontend));
        let owners = await assets.list_authorized();
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            // TODO: `user` here is a bootstrapper user, not backend user. // TODO: Add backend user.
            for (principal in controllers.vals()) {
                await assets.grant_permission({to_principal = principal; permission});
            };
            for (owner in owners.vals()) {
                await assets.revoke_permission({
                    of_principal = owner; // TODO: Why isn't it enough to remove `Principal.fromActor(this)`?
                    permission;
                });
            };
        };
        // Done above:
        // await ic.update_settings({
        //     canister_id = frontend;
        //     sender_canister_version = null;
        //     settings = {
        //         compute_allocation = null;
        //         // We don't include `indirect_canister_id` because it can't control without risk of ite beiing replaced.
        //         // I don't add more controllers, because controlling this is potentially unsafe.
        //         controllers = ?[backend_canister_id, indirect_canister_id, simple_indirect_canister_id, frontend];
        //         freezing_threshold = null;
        //         log_visibility = null;
        //         memory_allocation = null;
        //         reserved_cycles_limit = null;
        //         wasm_memory_limit = null;
        //     };
        // });
        await Data.deleteFrontendTweaker(frontend);
    };
}