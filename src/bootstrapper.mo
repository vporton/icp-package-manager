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
import {ic} "mo:ic"; // TODO: Use this in other places, too.


shared({caller = initialOwner}) actor class Bootstrap() = this {
    var owner = initialOwner;

    private func onlyOwner(caller: Principal) {
        if (caller != initialOwner) {
            Debug.trap("not an owner");
        };
    };

    // TODO: Allow to run it only once.
    // TODO: Should conform to `*_init()` standard?
    public shared({caller}) func init(): async () {
        onlyOwner(caller);

        Cycles.add<system>(1_000_000_000_000);
        indirect_caller := ?(await IndirectCaller.IndirectCaller());
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

    stable var ourModules: ?OurModules = null;

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
        let indirect_caller_v = getIndirectCaller();

        let can = await* Install._installModuleButDontRegister(getOurModules().pmFrontendModule, to_candid(()), null, indirect_caller_v, Principal.fromActor(this)); // PM frontend
        // assert Option.isNull(userToPM.get(caller)); // TODO: Lift this restriction.
        let subMap = HashMap.HashMap<Principal, Principal>(0, Principal.equal, Principal.hash);
        userToPM.put(caller, subMap);
        can;
    };

    public shared({caller}) func bootstrapBackend(frontend: Principal, repo: Common.RepositoryPartitionRO)
        : async {installationId: Common.InstallationId; canisterIds: [(Text, Principal)]}
    {
        Debug.print("A1");
        Cycles.add<system>(1_000_000_000_000);
        let indirect_caller_v = await IndirectCaller.IndirectCaller(); // a separate `IndirectCaller` for this PM

        // TODO: Allow to install only once.
        // PM backend. It (and frontend) will be registered as an (unnamed) module by the below called `*_init()`.
        Debug.print("A2");
        let can = await* Install._installModuleButDontRegister(
            getOurModules().pmBackendModule,
            to_candid(()),
            null, // ?(to_candid({frontend})), // TODO
            indirect_caller_v,
            Principal.fromActor(this),
        );
        Debug.print("A3");

        let #Wasm loc = getOurModules().pmBackendModule else {
            Debug.trap("missing PM backend");
        };
        Debug.print("A4");
        let pm: PackageManager.PackageManager = actor(Principal.toText(can));
        ignore await indirect_caller_v.call({
            canister = can;
            name = "setOwner";
            data = to_candid(Principal.fromActor(this));
        });
        await pm.setIndirectCaller(indirect_caller_v);
        // TODO: the order of below operations
        Debug.print("A5");
        Debug.print("A6");
        let inst = await pm.installPackageWithPreinstalledModules({ // FIXME: This fails
            canister = loc.0;
            packageName = "icpack";
            version = "0.0.1"; // TODO: should be `"stable"`
            preinstalledModules = [("frontend", frontend)];
            repo;
        });
        Debug.print("A7");
        await pm.registerNamedModule({
            installation = inst.installationId;
            canister = Principal.fromActor(indirect_caller_v);
            packageManager = can;
            moduleName = "indirect"; // TODO: a better name?
        });
        Debug.print("A8");
        await indirect_caller_v.setOwner(can);
        Debug.print("A9");
        await ic.update_settings({canister_id = Principal.fromActor(indirect_caller_v); sender_canister_version = null; settings = {
            controllers = ?[Principal.fromActor(indirect_caller_v)]; // FIXME: Should it be self-controlled?
            freezing_threshold = null;
            memory_allocation = null;
            compute_allocation = null;
            reserved_cycles_limit = null;
        }});
        Debug.print("A10");
        await pm.registerNamedModule({ // PM backend registers itself.
            installation = inst.installationId;
            canister = can;
            packageManager = can;
            moduleName = "backend";
        });
        Debug.print("A11");
        await ic.update_settings({canister_id = can; sender_canister_version = null; settings = {
            controllers = ?[can]; // self-controlled // FIXME: Should it also be user-controlled?
            freezing_threshold = null;
            memory_allocation = null;
            compute_allocation = null;
            reserved_cycles_limit = null;
        }});
        Debug.print("A12");
        await pm.setOwner(caller);
        switch (userToPM.get(caller)) {
            case (?subMap) {
                subMap.put(frontend, inst.canisterIds[0].1);
            };
            case null { Debug.trap("TODO") };
        };
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
