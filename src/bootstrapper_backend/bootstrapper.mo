import Common "../common";
import Install "../install";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import IC "mo:ic";

actor class Bootstrapper() = this {
    stable var newCanisterCycles = 600_000_000_000; // TODO: Edit it.

    // FIXME: Legible to DoS attack.
    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        initialIndirect: Principal;
        simpleIndirect: Principal;
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
        {canister_id};
    };

    // FIXME: Legible to DoS attack.
    public shared func bootstrapBackend({
        backendWasmModule: Common.SharedModule;
        indirectWasmModule: Common.SharedModule;
        simpleIndirectWasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
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

        for (canister_id in [backend_canister_id, indirect_canister_id, simple_indirect_canister_id].vals()) {
            // TODO: We can provide these setting initially and thus update just one canister.
            await IC.ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // We don't include `indirect_canister_id` because it can't control without risk of DoS.
                    controllers = ?[backend_canister_id, simple_indirect_canister_id, user]; // TODO: Should `user` be among controllers?    
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

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

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id; simpleIndirectPrincipal = simple_indirect_canister_id};
    };

    type PubKey = Blob;

    /// Frontend canisters belong to this canister. We move them to new owners.
    let frontendTweakers = HashMap.HashMap<Principal, PubKey>(1, Principal.equal, Principal.hash);
}