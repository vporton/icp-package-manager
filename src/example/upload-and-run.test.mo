// import RepositoryIndex "canister:RepositoryIndex";
import RepositoryIndex "../icp_summer_backend/RepositoryIndex";
import RepositoryPartition "../icp_summer_backend/RepositoryPartition";
import Common "../icp_summer_backend/common";
import PackageManager "../icp_summer_backend/package_manager";
import Counter "../example/counter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";

actor {
    public shared func main(wasm2: [Nat8]): async Nat {
        let wasm = Blob.fromArray(wasm2);
        Cycles.add<system>(1000_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        await index.init();

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
                wasms = [(Principal.fromActor(wasmPart), "0")]; // FIXME: not 0 in general
                dependencies = [];
                functions = [];
                permissions = [];
            };
        };
        let fullInfo: Common.FullPackageInfo = {
            packages = [("stable", info)];
            versionsMap = [];
        };
        await pPart.setFullPackageInfo("counter", fullInfo);

        Cycles.add<system>(1000_000_000_000_000);
        let pm = await PackageManager.PackageManager();
        let id = await pm.installPackage({
            part = pPart;
            packageName = "counter";
            version = "stable";
        });

        let installed = await pm.getInstalledPackage(id);
        let counter: Counter.Counter = actor(Principal.toText(installed.modules[0]));
        await counter.increase();
        let testValue = await counter.get();
        Debug.print("COUNTER: " # debug_show(testValue));
        testValue;
    };
}
