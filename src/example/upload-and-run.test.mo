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

actor {
    public shared func main(wasm2: [Nat8]): async (Principal, Common.InstallationId) {
        Debug.print("Creating a distro repository...");
        let wasm = Blob.fromArray(wasm2);
        Cycles.add<system>(1000_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        await index.init();

        Debug.print("Uploading WASM code...");
        let wasmPart0 = await index.getLastCanistersByPK("wasms");
        let wasmPart: RepositoryPartition.RepositoryPartition = actor(wasmPart0);
        await wasmPart.putAttribute("0", "w", #blob wasm); // FIXME: not 0 in general
        let pPart0 = await index.getLastCanistersByPK("main"); // FIXME: Receive it from `setFullPackageInfo`.
        let pPart: RepositoryPartition.RepositoryPartition = actor(pPart0); // TODO: Rename.

        let info: Common.PackageInfo = {
            base = {
                name = "counter";
                version = "1.0.0";
                shortDescription = "Counter variable";
                longDescription = "Counter variable controlled by a shared method";
            };
            specific = #real {
                modules = [#Wasm (Principal.fromActor(wasmPart), "0")]; // FIXME: not 0 in general
                dependencies = [];
                functions = [];
                permissions = [];
            };
        };
        let fullInfo: Common.FullPackageInfo = {
            packages = [("stable", info)];
            versionsMap = [];
        };
        Debug.print("Uploading package and versions description...");
        await pPart.setFullPackageInfo("counter", fullInfo);

        Cycles.add<system>(1000_000_000_000_000);
        Debug.print("Installing the ICP Package manager...");
        let pm = await PackageManager.PackageManager();
        Debug.print("Using the PM to install 'counter' package...");
        let id = await pm.installPackage({
            canister = Principal.fromActor(pPart); // FIXME
            packageName = "counter";
            version = "stable";
        });
        (Principal.fromActor(pm), id);
    };
}
