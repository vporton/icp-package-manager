import RBTree "mo:base/RBTree";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Asset "mo:assets-api";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";

// TODO: Functions in this canister are legible to non-returning-callee attack. Develop the strategy of updating this module.
//       Especially, we should preserve `frontendTweakers`.
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
            mainControllers = ?[Principal.fromActor(this), user, initialIndirect, simpleIndirect];
            user;
            cyclesAmount = newCanisterCycles;
        }); // TODO: This is a bug.
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
        frontendTweakers.put(canister_id, frontendTweakPubKey);
        frontendTweakerTimes.put(Time.now(), canister_id);
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
        repoPart: Common.RepositoryPartitionRO;
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

        // FIXME: Move it after installing, to set right permissions for the user.
        for (canister_id in [backend_canister_id, indirect_canister_id, simple_indirect_canister_id].vals()) {
            // TODO: We can provide these setting initially and thus update just one canister.
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // We don't include `indirect_canister_id` because it can't control without risk of ite being replaced.
                    // TODO: Check which canisters are necessary as controllers.
                    controllers = ?[simple_indirect_canister_id, user, indirect_canister_id, Principal.fromActor(this), backend_canister_id]; // TODO: Should `user` be among controllers?    
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

        await* tweakFrontend(frontend, frontendTweakPrivKey, {backend_canister_id; simple_indirect_canister_id; user});

        let backend = actor(Principal.toText(backend_canister_id)): actor {
            installPackageWithPreinstalledModules: shared ({
                whatToInstall: {
                    #package;
                    // #simplyModules : [(Text, Common.SharedModule)]; // TODO
                };
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryPartitionRO; 
                user: Principal;
                indirectCaller: Principal;
                /// Additional packages to install after bootstrapping.
                additionalPackages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryPartitionRO;
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
          additionalPackages = [{packageName = "example"; version = "0.0.1"; repo = repoPart}];
        });

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id; simpleIndirectPrincipal = simple_indirect_canister_id};
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Frontend canisters belong to this canister. We move them to new owners.
    let frontendTweakers = HashMap.HashMap<Principal, PubKey>(1, Principal.equal, Principal.hash); // TODO: Make it stable?
    let frontendTweakerTimes = RBTree.RBTree<Time.Time, Principal>(Int.compare); // TODO: Make it stable?

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
        do { // clean memory by removing old entries
            let threshold = Time.now() - 2700 * 1_000_000_000; // 45 min // TODO: make configurable?
            var i = RBTree.iter(frontendTweakerTimes.share(), #fwd);
            label x loop {
                let ?(time, principal) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    frontendTweakerTimes.delete(time);
                    frontendTweakers.delete(principal);
                } else {
                    break x;
                };
            };
        };
        let ?pubKey = frontendTweakers.get(frontend) else {
            Debug.trap("no such frontend or key expired");
        };
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
        frontendTweakers.delete(frontend);
    };
}