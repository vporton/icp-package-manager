import IndirectCaller "package_manager_backend/indirect_caller";
import RepositoryIndex "repository_backend/RepositoryIndex";
import RepositoryPartition "repository_backend/RepositoryPartition";
import Common "common";
import Install "install";
import PackageManager "package_manager_backend/package_manager";
import Counter "example/counter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Cycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Option "mo:base/Option";

shared({caller = intitialOwner}) actor class Bootstrap() {
    var owner = intitialOwner;

    private func onlyOwner(caller: Principal) {
        if (caller != intitialOwner) {
            Debug.trap("not an owner");
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public query func getOwner(): async Principal {
        owner;
    };

    /// user -> (frontend -> backend)
    let userToPM = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Principal>>(1, Principal.equal, Principal.hash);

    public query({caller}) func getUserPMInfo(): async [(Principal, Principal)] {
        switch (userToPM.get(caller)) {
            case (?a) Iter.toArray(a.entries());
            case null [];
        };
    };

    type OurModules = {
        pmFrontendModule: Common.Module;
        pmBackendModule: Common.Module;
    };

    var ourModules: ?OurModules = null;

    public shared({caller}) func setOurModules(m: OurModules) {
        onlyOwner(caller);

        ourModules := ?m;
    };

    // TODO: Support multiple sets of modules per `this`.
    private func getOurModules(): OurModules {
        let ?m = ourModules else {
            Debug.trap("modules not initialized");
        };
        m;
    };

    /// TODO: Move to another canister?
    public shared({caller}) func bootstrapIndex(): async Principal {
        Debug.print("Creating a distro repository...");
        Cycles.add<system>(300_000_000_000_000);
        let index = await RepositoryIndex.RepositoryIndex();
        // await index.init(); // TODO
        Principal.fromActor(index);
    };

    public shared({caller}) func bootstrapFrontend() : async Principal {
        Cycles.add<system>(1_000_000_000_000);
        let indirect_caller_v = await IndirectCaller.IndirectCaller(); // yes, a separate `IndirectCaller` for this PM
        indirect_caller := ?indirect_caller_v;

        let can = await* Install._installModule(getOurModules().pmFrontendModule, to_candid(()), null, getIndirectCaller(), null); // PM frontend
        // assert Option.isNull(userToPM.get(caller)); // TODO: Lift this restriction.
        let subMap = HashMap.HashMap<Principal, Principal>(0, Principal.equal, Principal.hash);
        userToPM.put(caller, subMap);
        can;
    };

    public shared({caller}) func bootstrapBackend(frontend: Principal)
        : async {installationId: Common.InstallationId; canisterIds: [(Text, Principal)]}
    {
        Cycles.add<system>(1_000_000_000_000);
        let indirect_caller_v = await IndirectCaller.IndirectCaller(); // yes, a separate `IndirectCaller` for this PM

        // TODO: Allow to install only once.
        // PM backend. It (and frontend) will be registered as an (unnamed) module by the below called `*_init()`.
        let can = await* Install._installModule(
            getOurModules().pmBackendModule,
            to_candid(()),
            ?(to_candid({frontend})),
            indirect_caller_v,
            null,
        );

        let #Wasm loc = getOurModules().pmBackendModule else {
            Debug.trap("missing PM backend");
        };
        let pm: PackageManager.PackageManager = actor(Principal.toText(can));
        let inst = await pm.installPackageWithPreinstalledModules({
            canister = loc.0;
            packageName = "icpack";
            version = "0.0.1"; // TODO: should be `"stable"`
            preinstalledModules = [("frontend", frontend)];
        });
        switch (userToPM.get(caller)) {
            case (?subMap) {
                subMap.put(frontend, inst.canisterIds[0].1);
            };
            case null { Debug.trap("TODO") };
        };
        await pm.setOwner(caller);
        inst;
    };

    stable var indirect_caller: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller2 = indirect_caller else {
            Debug.trap("indirect_caller not initialized");
        };
        indirect_caller2;
    };
}
