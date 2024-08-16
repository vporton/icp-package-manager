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
    public shared func main(wasm/*2*/: Blob/*[Nat8]*/): async (Principal, Common.InstallationId) {
        Debug.print("Creating a distro repository...");
        Cycles.add<system>(300_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        Cycles.add<system>(300_000_000_000_000);
        let IC = actor ("aaaaa-aa") : actor {
            deposit_cycles : shared { canister_id : Principal } -> async ();
        };
        await IC.deposit_cycles({ canister_id = Principal.fromActor(index) });
        await index.init();

        Debug.print("Uploading WASM code...");
        // let wasm = Blob.fromArray(wasm2);
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

        Debug.print("Installing the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        let pm = await PackageManager.PackageManager();
        Cycles.add<system>(100_000_000_000_000);
        await IC.deposit_cycles({ canister_id = Principal.fromActor(pm) });
        Debug.print("Bootstrapping the ICP Package manager...");
        Cycles.add<system>(100_000_000_000_000);
        await pm.init(Principal.fromActor(pPart), "0.0.1", [Principal.fromActor(wasmPart)]);
        Debug.print("Using the PM to install 'counter' package...");
        let id = await pm.installPackage({
            canister = Principal.fromActor(pPart); // FIXME
            packageName = "counter";
            version = "stable";
        });
        (Principal.fromActor(pm), id);
    };
}
