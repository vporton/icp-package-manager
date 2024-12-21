import Common "../common";
import Install "../install";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import IC "mo:ic";

actor class Bootstrapper() = this {
    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        initialIndirect: Principal;
    }): async {canister_id: Principal} {
        let {canister_id} = await* Install.myCreateCanister({mainController = [Principal.fromActor(this), user, initialIndirect]; user}); // TODO: This is a bug.
        await* Install.myInstallCode({
            installationId = 0;
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // TODO: This is a bug.
            initialIndirect;
            user;
        });
        {canister_id};
    };

    public shared func bootstrapBackend({
        backendWasmModule: Common.SharedModule;
        indirectWasmModule: Common.SharedModule;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
    }): async {backendPrincipal: Principal; indirectPrincipal: Principal} {
        // TODO: Create and update settings for two canisters in parallel.
        // TODO: No need to create many initial controllers.
        Debug.print("A1");
        let {canister_id = backend_canister_id} = await* Install.myCreateCanister({
            mainController = [Principal.fromActor(this), user];
            user;
        }); // TODO: This is a bug.
        Debug.print("A2");
        let {canister_id = indirect_canister_id} = await* Install.myCreateCanister({
            mainController = [backend_canister_id, Principal.fromActor(this), user];
            user;
        });
        Debug.print("A3");
        for (canister_id in [backend_canister_id, indirect_canister_id].vals()) {
            await IC.ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    controllers = ?[indirect_canister_id, backend_canister_id, Principal.fromActor(this), user]; // FIXME
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

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
            user;
        });
        Debug.print("A4");

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
            user;
        });
        Debug.print("A5");

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

        {backendPrincipal = backend_canister_id; indirectPrincipal = indirect_canister_id};
    };
}