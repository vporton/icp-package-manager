import Asset "mo:assets-api";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";
import Data "canister:BootstrapperData";

// FIXME: Functions in this canister are legible to non-returning-callee attack. Develop the strategy of updating this module.
//        Especially, we should preserve `frontendTweakers`.
actor class Bootstrapper() = this {
    stable var newCanisterCycles = 600_000_000_000; // TODO: Edit it.

    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        initialIndirect: Principal;
        simpleIndirect: Principal;
        frontendTweakPubKey: PubKey;
    }): async {canister_id: Principal} {
        let {canister_id} = await* Install.myCreateCanister({
            mainControllers = ?[Principal.fromActor(this), user, initialIndirect, simpleIndirect]; // TODO: This is a bug.
            user;
            cyclesAmount = newCanisterCycles;
        });
        await* Install.myInstallCode({
            installationId = 0;
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // modified by frontend tweak below. // FIXME: check
            initialIndirect;
            simpleIndirect;
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
        repoPart: Common.RepositoryIndexRO; // TODO: Rename.
    }): async {backendPrincipal: Principal; indirectPrincipal: Principal; simpleIndirectPrincipal: Principal} {
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
            canister_id = backend_canister_id;
            wasmModule = Common.unshareModule(backendWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                initialIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper;
            initialIndirect = indirect_canister_id;
            simpleIndirect = simple_indirect_canister_id;
            user;
        });
        await* Install.myInstallCode({
            installationId = 0;
            canister_id = indirect_canister_id;
            wasmModule = Common.unshareModule(indirectWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                initialIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper = backend_canister_id;
            initialIndirect = indirect_canister_id;
            simpleIndirect = simple_indirect_canister_id;
            user;
        });
        await* Install.myInstallCode({
            installationId = 0;
            canister_id = simple_indirect_canister_id;
            wasmModule = Common.unshareModule(simpleIndirectWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                initialIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper = backend_canister_id;
            initialIndirect = indirect_canister_id;
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
        //     setIndirectCaller: (indirect_caller: IndirectCaller) -> async (); 
        //     addOwner: (newOwner: Principal) -> async (); 
        //     removeOwner: (oldOwner: Principal) -> async (); 
        // };

        await* tweakFrontend(frontend, frontendTweakPrivKey, {backend_canister_id; simple_indirect_canister_id; user});

        // FIXME: Move below?
        for (canister_id in [backend_canister_id, indirect_canister_id, simple_indirect_canister_id].vals()) {
            // TODO: We can provide these setting initially and thus update just one canister.
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // TODO: Check which canisters are necessary as controllers.
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
                repo: Common.RepositoryIndexRO; 
                user: Principal;
                indirectCaller: Principal;
                /// Additional packages to install after bootstrapping.
                additionalPackages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryIndexRO;
                }];
                preinstalledModules: [(Text, Principal)];
            }) -> async {minInstallationId: Common.InstallationId};
        };
        ignore await backend.installPackageWithPreinstalledModules({ // FIXME: Remove `await` not to run into a DoS-attack.
          whatToInstall = #package;
          packageName = "icpack";
          version = "0.0.1"; // TODO: should be `stable`.
          preinstalledModules = [
            ("backend", backend_canister_id),
            ("frontend", frontend),
            ("indirect", indirect_canister_id),
            ("simple_indirect", simple_indirect_canister_id),
          ];
          repo = repoPart;
          user;
          indirectCaller = indirect_canister_id;
          additionalPackages = [{packageName = "example"; version = "0.0.1"; repo = repoPart}]; // FIXME: Should not be here.
        });

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id; simpleIndirectPrincipal = simple_indirect_canister_id};
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Internal. Updates controllers and owners of the frontend.
    private func tweakFrontend(
        frontend: Principal,
        privKey: PrivKey,
        {
            // backend_canister_id: Principal;
            simple_indirect_canister_id: Principal;
            user: Principal;
        },
    ): async* () {
        let pubKey = await Data.getFrontendTweaker(frontend);
        if (Sha256.fromBlob(#sha256, privKey) != pubKey) {
            Debug.trap("access denied");
        };
        let assets: Asset.AssetCanister = actor(Principal.toText(frontend));
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            await assets.grant_permission({
                to_principal = simple_indirect_canister_id;
                permission;
            });
            await assets.revoke_permission({
                of_principal = Principal.fromActor(this);
                permission;
            });
        };
        await ic.update_settings({
            canister_id = frontend;
            sender_canister_version = null;
            settings = {
                compute_allocation = null;
                // We don't include `indirect_canister_id` because it can't control without risk of ite beiing replaced.
                controllers = ?[simple_indirect_canister_id, user]; // TODO: Should `user` be among controllers?    
                freezing_threshold = null;
                log_visibility = null;
                memory_allocation = null;
                reserved_cycles_limit = null;
                wasm_memory_limit = null;
            };
        });
        await Data.deleteFrontendTweaker(frontend);
    };
}