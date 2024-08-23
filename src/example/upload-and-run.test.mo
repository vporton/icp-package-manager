// import RepositoryIndex "canister:RepositoryIndex";
import RepositoryIndex "../repository_backend/RepositoryIndex";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import Common "../common";
import PackageManager "../package_manager_backend/package_manager";
import Counter "../example/counter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

actor {
    /// FIXME: Move to production from testing.
    ///
    /// `version` is expected to be something like `"stable"`.
    private func bootstrapPackageManager(packages: [Common.Location], version: Text)
        : async* [{installationId: Common.InstallationId; canisterIds: [Principal]}]
    {
        Debug.print("Installing the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        let pm = await PackageManager.PackageManager();
        Debug.print("Bootstrapping the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        await pm.init();
        let b = Buffer.Buffer<{installationId: Common.InstallationId; canisterIds: [Principal]}>(Array.size(packages));
        for (p in packages.vals()) {
            Debug.print("Using the PM to install packages...");
            let id = await pm.installPackage({
                canister = p.0;
                packageName = p.1;
                version = version;
            });
            b.add(id);
        };
        Buffer.toArray(b);
    };

    // FIXME: Also upload package manager.
    public shared func main(pmWasm: Blob, pmFrontendWasm: Blob, pmFrontend: Principal, testWasm: Blob)
        : async [{installationId: Common.InstallationId; canisterIds: [Principal]}]
    {
        Debug.print("Creating a distro repository...");
        Cycles.add<system>(300_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        await index.init();

        // TODO: Install to correct subnet.
        Debug.print("Uploading WASM code...");
        let {canister = pmWasmPart; id = pmWasmId} = await index.uploadWasm(pmWasm);
        let {canister = pmFrontendPart; id = pmFrontendId} = await index.uploadWasm(pmFrontend);
        let {canister = counterWasmPart; id = counterWasmId} = await index.uploadWasm(testWasm);

        Debug.print("Uploading package and versions description...");
        let pmInfo: Common.PackageInfo = {
            base = {
                name = "icpack";
                version = "0.0.1";
                shortDescription = "Package manager";
                longDescription = "Manager for installing ICP app to user's subnet";
            };
            specific = #real {
                modules = [#Wasm (pmWasmPart, pmWasmId), #Assets {wasm = (pmFrontendPart, pmFrontendId); assets = pmFrontend}];
                dependencies = [];
                functions = [];
                permissions = [];
            };
        };
        let pmFullInfo: Common.FullPackageInfo = {
            packages = [("stable", pmInfo)];
            versionsMap = [];
        };
        let counterInfo: Common.PackageInfo = {
            base = {
                name = "counter";
                version = "1.0.0";
                shortDescription = "Counter variable";
                longDescription = "Counter variable controlled by a shared method";
            };
            specific = #real {
                modules = [#Wasm (counterWasmPart, counterWasmId)];
                dependencies = [];
                functions = [];
                permissions = [];
            };
        };
        let counterFullInfo: Common.FullPackageInfo = {
            packages = [("stable", counterInfo)];
            versionsMap = [];
        };
        let {canister = pmPart} = await index.createPackage("icpack", pmFullInfo);
        let {canister = counterPart} = await index.createPackage("counter", counterFullInfo);

        // TODO: Use a correct subnet.
        await* bootstrapPackageManager([(pmPart, "icpack"), (counterPart, "counter")], "stable");
    };
}
