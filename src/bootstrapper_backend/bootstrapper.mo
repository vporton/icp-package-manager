import IndirectCaller "../package_manager_backend/indirect_caller";
import RepositoryIndex "../repository_backend/RepositoryIndex";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import Common "../common";
import Install "../install";
import PackageManager "../package_manager_backend/package_manager";
import Counter "../example/counter";
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

        await* Install._installModuleButDontRegister(getOurModules().pmFrontendModule, to_candid(()), null, indirect_caller_v, Principal.fromActor(this), caller); // PM frontend
        // Don't install package here, because we don't have where to register it.
    };

    public shared({caller}) func bootstrapBackend(frontend: Principal, repo: Common.RepositoryPartitionRO)
        : async {installationId: Common.InstallationId; backend: Principal}
    {
        Cycles.add<system>(1_000_000_000_000);
        let indirect_caller_v = await IndirectCaller.IndirectCaller(); // a separate `IndirectCaller` for this PM

        // TODO: Allow to install only once.
        // PM backend. It (and frontend) will be registered as an (unnamed) module by the below called `*_init()`. // FIXME
        Debug.print("A1");
        let can = await* Install._installModuleButDontRegister(
            getOurModules().pmBackendModule,
            to_candid(()),
            null, // ?(to_candid({frontend})), // TODO
            indirect_caller_v,
            Principal.fromActor(this),
            caller,
        );
        Debug.print("A2");

        let #Wasm loc = getOurModules().pmBackendModule else {
            Debug.trap("missing PM backend");
        };
        let pm: PackageManager.PackageManager = actor(Principal.toText(can));
        Debug.print("A3");
        // await pm.setOwner(caller); // set by *_init()
        Debug.print("A4");
        // await pm.setIndirectCaller(indirect_caller_v); // set by *_init()
        Debug.print("A5");
        await indirect_caller_v.setOwner(can);
        // TODO: the order of below operations
        Debug.print("A6");
        let inst = await pm.installPackageWithPreinstalledModules({
            packageName = "icpack";
            version = "0.0.1"; // TODO: should be `"stable"`
            preinstalledModules = [("frontend", frontend)];
            repo;
            caller;
            callback = ?bootstrapBackendCallback;
        });
        Debug.print("A7");
        {installationId = inst.installationId; backend = can};
    };

    public shared({caller}) func bootstrapBackendCallback({
        installationId: Common.InstallationId;
        can: Principal;
        caller: Principal;
    }): async () {
        let indirect_caller_v = getIndirectCaller();

        if (caller != Principal.fromActor(indirect_caller_v)) {
            Debug.trap("callback only from indirect_caller");
        };

        let pm: PackageManager.PackageManager = actor(Principal.toText(can));
        await pm.registerNamedModule({
            installation = installationId;
            canister = Principal.fromActor(indirect_caller_v);
            packageManager = can;
            moduleName = "indirect"; // TODO: a better name?
        });
        await ic.update_settings({canister_id = Principal.fromActor(indirect_caller_v); sender_canister_version = null; settings = {
            controllers = ?[can, Principal.fromActor(indirect_caller_v)];
            freezing_threshold = null;
            memory_allocation = null;
            compute_allocation = null;
            reserved_cycles_limit = null;
        }});
        await pm.registerNamedModule({ // PM backend registers itself.
            installation = installationId;
            canister = can;
            packageManager = can;
            moduleName = "backend";
        });
        await ic.update_settings({canister_id = can; sender_canister_version = null; settings = {
            controllers = ?[can, caller]; // self-controlled
            freezing_threshold = null;
            memory_allocation = null;
            compute_allocation = null;
            reserved_cycles_limit = null;
        }});
        await pm.setOwner(caller);
    };

    stable var indirect_caller: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller2 = indirect_caller else {
            Debug.trap("indirect_caller not initialized");
        };
        indirect_caller2;
    };
}
