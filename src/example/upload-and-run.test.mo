import RepositoryIndex "canister:RepositoryIndex";
import RepositoryPartition "../icp_summer_backend/RepositoryPartition";
import Common "../icp_summer_backend/common";
import PackageManager "../icp_summer_backend/package_manager";
import Counter "../example/counter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

actor {
    public shared func main(wasm2: [Nat8]) {
        let wasm = Blob.fromArray(wasm2);
        let index = RepositoryIndex;

        let part0 = await index.getLastCanistersByPK("wasms");
        let part: RepositoryPartition.RepositoryPartition = actor(part0);
        await part.putAttribute("0", "w", #blob wasm); // FIXME: not 0 in general

        let info: Common.PackageInfo = {
            base = {
                name = "counter";
                version = "1.0.0";
                shortDescription = "Counter variable";
                longDescription = "Counter variable controlled by a shared method";
            };
            specific = #real {
                wasms = [(Principal.fromActor(part), "0")]; // FIXME: not 0 in general
                dependencies = [];
                functions = [];
                permissions = [];

            };
        };
        let fullInfo: Common.FullPackageInfo = {
            packages = [("stable", info)];
            versionsMap = [];
        };
        await part.setFullPackageInfo("counter", fullInfo);

        let pm = await PackageManager.PackageManager();
        let id = await pm.installPackage({
            part;
            packageName = "counter";
            version = "1.0.0";
        });

        let installed = await pm.getInstalledPackage(id);
        let counter: Counter.Counter = actor(Principal.toText(installed.modules[0]));
        await counter.increase();
    };
}
