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
    // TODO: It seems that below `deposit_cycles` are superfluous.
    public shared func main(wasm: Blob): async (Principal, Common.InstallationId) {
        Debug.print("Creating a distro repository...");
        Cycles.add<system>(300_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        Cycles.add<system>(300_000_000_000_000);
        let IC = actor ("aaaaa-aa") : actor {
            deposit_cycles : shared { canister_id : Principal } -> async ();
        };
        await IC.deposit_cycles({ canister_id = Principal.fromActor(index) });
        await index.init();

        // TODO: Install to correct subnet.
        Debug.print("Uploading WASM code...");
        let {canister = wasmPart; id = wasmId} = await index.uploadWasm(wasm);

        let info: Common.PackageInfo = {
            base = {
                name = "counter";
                version = "1.0.0";
                shortDescription = "Counter variable";
                longDescription = "Counter variable controlled by a shared method";
            };
            specific = #real {
                modules = [#Wasm (wasmPart, wasmId)];
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
        let pPart0 = await index.getLastCanisterByPK("main"); // FIXME!!!
        let pPart: RepositoryPartition.RepositoryPartition = actor(pPart0);
        await pPart.setFullPackageInfo("counter", fullInfo);

        Debug.print("Installing the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        let pm = await PackageManager.PackageManager();
        Cycles.add<system>(100_000_000_000_000);
        await IC.deposit_cycles({ canister_id = Principal.fromActor(pm) });
        Debug.print("Bootstrapping the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        await pm.init(Principal.fromActor(pPart), "0.0.1", [wasmPart]);
        Debug.print("Using the PM to install 'counter' package...");
        let id = await pm.installPackage({
            canister = Principal.fromActor(pPart); // FIXME
            packageName = "counter";
            version = "stable";
        });
        (Principal.fromActor(pm), id);
    };
}
