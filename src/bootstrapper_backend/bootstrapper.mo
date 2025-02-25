/// This module is legible to non-returning-function attack. Throw it away if it fails this way.
/// Data is stored in `bootstrapper_data` instead.
import Asset "mo:assets-api";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";
import Data "canister:bootstrapper_data";

actor class Bootstrapper() = this {
    stable var newCanisterCycles = 600_000_000_000; // TODO: Edit it. (Move to `bootstrapper_data`?)

    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        frontendTweakPubKey: PubKey;
    }): async {canister_id: Principal} {
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
    public shared func bootstrapBackend({
        backendWasmModule: Common.SharedModule;
        indirectWasmModule: Common.SharedModule;
        simpleIndirectWasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        frontend: Principal;
        frontendTweakPrivKey: PrivKey;
        repo: Common.RepositoryRO;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async {backendPrincipal: Principal; mainIndirectPrincipal: Principal; simpleIndirectPrincipal: Principal} {
        let {canister_id = backend_canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
            user;
            cyclesAmount = newCanisterCycles;
        });
        let {canister_id = indirect_canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
            user;
            cyclesAmount = newCanisterCycles;
        });
        let {canister_id = simple_indirect_canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
            user;
            cyclesAmount = newCanisterCycles;
        });

        await* Install.myInstallCode({
            installationId = 0;
            upgradeId = null;
            canister_id = backend_canister_id;
            wasmModule = Common.unshareModule(backendWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                mainIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper;
            mainIndirect = indirect_canister_id;
            simpleIndirect = simple_indirect_canister_id;
            user;
        });
        await* Install.myInstallCode({
            installationId = 0;
            upgradeId = null;
            canister_id = indirect_canister_id;
            wasmModule = Common.unshareModule(indirectWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                mainIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper = backend_canister_id;
            mainIndirect = indirect_canister_id;
            simpleIndirect = simple_indirect_canister_id;
            user;
        });
        await* Install.myInstallCode({
            installationId = 0;
            upgradeId = null;
            canister_id = simple_indirect_canister_id;
            wasmModule = Common.unshareModule(simpleIndirectWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                mainIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper = backend_canister_id;
            mainIndirect = indirect_canister_id;
            simpleIndirect = simple_indirect_canister_id;
            user;
        });

        // let _indirect = actor (Principal.toText(indirect_canister_id)) : actor {
        //     addOwner: (newOwner: Principal) -> async ();
        //     setOurPM: (pm: Principal) -> async ();
        //     removeOwner: (oldOwner: Principal) -> async (); 
        // };

        // let _backend = actor (Principal.toText(backend_canister_id)) : actor {
        //     // setOwners: (newOwners: [Principal]) -> async ();
        //     setMainIndirect: (main_indirect: MainIndirect) -> async (); 
        //     addOwner: (newOwner: Principal) -> async (); 
        //     removeOwner: (oldOwner: Principal) -> async (); 
        // };

        await* tweakFrontend(frontend, frontendTweakPrivKey, {
            simple_indirect_canister_id; indirect_canister_id; backend_canister_id; user;
        });

        for (canister_id in [backend_canister_id, indirect_canister_id, simple_indirect_canister_id, frontend].vals()) {
            // TODO: We can provide these setting initially and thus update just one canister.
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // `indirect_canister_id` here is only for the package manager package:
                    controllers = ?[simple_indirect_canister_id, indirect_canister_id, backend_canister_id, user];
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

        let backend = actor(Principal.toText(backend_canister_id)): actor {
            installPackageWithPreinstalledModules: shared ({
                whatToInstall: {
                    #package;
                    // #simplyModules : [(Text, Common.SharedModule)]; // TODO
                };
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
        ignore await backend.installPackageWithPreinstalledModules({
          whatToInstall = #package;
          packageName = "icpack";
          version = "0.0.1"; // TODO: should be `stable`.
          preinstalledModules = [
            ("backend", backend_canister_id),
            ("frontend", frontend),
            ("indirect", indirect_canister_id),
            ("simple_indirect", simple_indirect_canister_id),
          ];
          repo = repo;
          user;
          mainIndirect = indirect_canister_id;
          additionalPackages;
        });

        {backendPrincipal = backend_canister_id; mainIndirectPrincipal = indirect_canister_id; simpleIndirectPrincipal = simple_indirect_canister_id};
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Internal. Updates controllers and owners of the frontend.
    private func tweakFrontend(
        frontend: Principal,
        privKey: PrivKey,
        {
            backend_canister_id: Principal;
            simple_indirect_canister_id: Principal;
            indirect_canister_id: Principal;
            user: Principal;
        },
    ): async* () {
        let pubKey = await Data.getFrontendTweaker(frontend);
        if (Sha256.fromBlob(#sha256, privKey) != pubKey) {
            Debug.trap("access denied");
        };
        let assets: Asset.AssetCanister = actor(Principal.toText(frontend));
        let owners = await assets.list_authorized();
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            // TODO: `user` here is a bootstrapper user, not backend user. // TODO: Add backend user.
            for (principal in [simple_indirect_canister_id, indirect_canister_id, backend_canister_id, user].vals()) {
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