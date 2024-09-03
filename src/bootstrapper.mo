import RepositoryIndex "repository_backend/RepositoryIndex";
import RepositoryPartition "repository_backend/RepositoryPartition";
import Common "common";
import PackageManager "package_manager_backend/package_manager";
import Counter "example/counter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

actor Bootstrap {
    public shared({caller}) func bootstrapIndex(/*pmWasm: Blob,*/ pmFrontendWasm: Blob, pmFrontend: Principal/*, testWasm: Blob*/)
        : async {canisterIds: [Principal]}
    {
        Debug.print("Creating a distro repository...");
        Cycles.add<system>(300_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        await index.init();

        // TODO: Install to correct subnet.
        Debug.print("Uploading WASM code...");
        // let {canister = pmWasmPart; id = pmWasmId} = await index.uploadWasm(pmWasm);
        let {canister = pmFrontendPart; id = pmFrontendId} = await index.uploadWasm(pmFrontendWasm);
        // let {canister = counterWasmPart; id = counterWasmId} = await index.uploadWasm(testWasm);

        Debug.print("Uploading package and versions description...");
        let pmInfo: Common.PackageInfo = {
            base = {
                name = "icpack";
                version = "0.0.1";
                shortDescription = "Package manager";
                longDescription = "Manager for installing ICP app to user's subnet";
            };
            specific = #real {
                modules = [#Assets {wasm = (pmFrontendPart, pmFrontendId); assets = actor(Principal.toText(pmFrontend))}];
                extraModules = [(null, [#Wasm (pmWasmPart, pmWasmId)])];
                dependencies = [];
                functions = [];
                permissions = [];
            };
        };
        let pmFullInfo: Common.FullPackageInfo = {
            packages = [("stable", pmInfo)];
            versionsMap = [];
        };
        // FIXME: Move and uncomment.
        // let counterInfo: Common.PackageInfo = {
        //     base = {
        //         name = "counter";
        //         version = "1.0.0";
        //         shortDescription = "Counter variable";
        //         longDescription = "Counter variable controlled by a shared method";
        //     };
        //     specific = #real {
        //         modules = [#Wasm (counterWasmPart, counterWasmId)];
        //         extraModules = [];
        //         dependencies = [];
        //         functions = [];
        //         permissions = [];
        //     };
        // };
        // let counterFullInfo: Common.FullPackageInfo = {
        //     packages = [("stable", counterInfo)];
        //     versionsMap = [];
        // };
        let {canister = pmPart} = await index.createPackage("icpack", pmFullInfo);
        // let {canister = counterPart} = await index.createPackage("counter", counterFullInfo);

        {canisterIds = [pmPart/*, counterPart*/]};
    };

    public shared({caller}) func bootstrapFrontend(module_: Common.Module, version: Text)
        : async* [{installationId: Common.InstallationId; canisterIds: [Principal]}]
    {
        // FIXME: Give cycles to it.
        await Install._installModule(module_, to_candid(())); // PM frontend
    };

    public shared({caller}) func bootstrapBackend(module_: Common.Module, version: Text)
        : async* [{installationId: Common.InstallationId; canisterIds: [Principal]}]
    {
        Cycles.add<system>(1_000_000_000_000); // FIXME
        let indirect_caller_v = await IndirectCaller.IndirectCaller();

        // FIXME: Give cycles to it.
        // FIXME: Allow to install only once.
        // FIXME: Check `to_candid` API matches in here and backend; standardize it
        let can = await Install._installModule(module_, to_candid({indirect_caller_v})); // PM backend

        let #Wasm loc = module_ else {
            Debug.trap("missing PM backend");
        };
        let pm: PackageManager.PackageManager = actor(can);
        await pm.installPackageWithPreinstalledModules({
            canister = loc.0;
            packageName = "icpack";
            version = "0.0.1"; // TODO: should be `"stable"`
            preinstalledModules = [can];
        });
    };
}
