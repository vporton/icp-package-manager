import Asset "mo:assets-api";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import IC "mo:ic";
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
            packageManagerOrBootstrapper = Principal.fromActor(this); // TODO: This is a bug.
            initialIndirect;
            simpleIndirect;
            user;
        });
        frontendTweakers.put(canister_id, frontendTweakPubKey);
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

        for (canister_id in [backend_canister_id, indirect_canister_id, simple_indirect_canister_id].vals()) {
            // TODO: We can provide these setting initially and thus update just one canister.
            await IC.ic.update_settings({
                canister_id;
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
        };

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id; simpleIndirectPrincipal = simple_indirect_canister_id};
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Frontend canisters belong to this canister. We move them to new owners.
    let frontendTweakers = HashMap.HashMap<Principal, PubKey>(1, Principal.equal, Principal.hash); // TODO: Make it stable?

    /// Internal. Updates controllers and owners of the frontend.
    private func tweakFrontend(
        frontend: Principal,
        privKey: PrivKey,
        {
            backend_canister_id: Principal;
            simple_indirect_canister_id: Principal;
            user: Principal;
        },
    ): async* () {
        let ?pubKey = frontendTweakers.get(frontend) else {
            Debug.trap("no such frontend");
        };
        if (Sha256.fromBlob(#sha256, privKey) != pubKey) {
            Debug.trap("access denied");
        };
        // FIXME: Make `simple_indirect_canister_id` able to use it.
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
        await IC.ic.update_settings({
            canister_id = frontend;
            sender_canister_version = null;
            settings = {
                compute_allocation = null;
                // We don't include `indirect_canister_id` because it can't control without risk of ite beiing replaced.
                // FIXME: Should exclude `backend` here and in other places?
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