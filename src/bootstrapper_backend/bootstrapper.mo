import Common "../common";

actor Bootstrapper {
    public shared func bootstrapFrontend({
        wasmModule: Common.SharedModule;
        installArg: Blob;
        user: Principal;
        initialIndirect: Principal;
    }): async {canister_id: Principal} {
        let {canister_id} = await* myCreateCanister({mainController = Principal.fromActor(this); user}); // TODO: This is a bug.
        await* myInstallCode({
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
        frontend: Principal;
        backendWasmModule: Common.SharedModule;
        indirectWasmModule: Common.SharedModule;
        user: Principal;
        repo: Common.RepositoryPartitionRO;
        packageManagerOrBootstrapper: Principal;
    }): async {backendPrincipal: Principal; indirectPrincipal: Principal} {
        // TODO: Create and run two canisters in parallel.
        Debug.print("A1");
        let {canister_id = backend_canister_id} = await* myCreateCanister({mainController = Principal.fromActor(this); user}); // TODO: This is a bug.
        Debug.print("A2");
        let {canister_id = indirect_canister_id} = await* myCreateCanister({mainController = backend_canister_id; user});
        Debug.print("A3");

        await* myInstallCode({
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

        await* myInstallCode({
            installationId = 0;
            canister_id = indirect_canister_id;
            wasmModule = Common.unshareModule(indirectWasmModule);
            installArg = to_candid({
                installationId = 0; // TODO
                initialIndirect = indirect_canister_id;
            });
            packageManagerOrBootstrapper = backend_canister_id;
            initialIndirect;
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