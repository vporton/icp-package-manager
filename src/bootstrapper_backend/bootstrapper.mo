/// FIXME: Rewrite.
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
import TrieMap "mo:base/TrieMap";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import {ic} "mo:ic"; // TODO: Use this in other places, too.
import cycles_ledger "canister:cycles_ledger";
import bootstrapperIndirectCaller "canister:BootstrapperIndirectCaller"; // TODO: Rename to signify, it is only for bootstrapper.

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
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public query func getOwner(): async Principal {
        owner;
    };

    type OurModules = {
        pmFrontendModule: Common.SharedModule;
        pmBackendModule: Common.SharedModule;
        pmIndirectCallerModule: Common.SharedModule;
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

    // TODO: Remove old elements to save space.
    let bootstrapIds = TrieMap.TrieMap<Nat, Principal>(Nat.equal, Common.IntHash);
    var nextBootstrapId = 0;

    public shared func getBootstrappedCanister(i: Nat): async Principal {
        let ?v = bootstrapIds.get(i) else {
            Debug.trap("no such bootstrapped canister");
        };
        v;
    };

    /// FIXME: Wrong.
    public shared({caller}) func bootstrapFrontend(): async {installationId: Common.InstallationId; frontendId: Nat} {
        let frontendId = nextBootstrapId;
        nextBootstrapId += 1;

        // FIXME
        // let frontendPrincipal = getOurModules().pmFrontendModule;
        // let {installationId} = await* Install._installModulesGroup({
        //     indirectCaller = actor(Principal.toText(Principal.fromActor(bootstrapperIndirectCaller))); // TODO: why so complex?
        //     whatToInstall = #bootstrap([
        //         ("frontend", Common.extractModule(frontendPrincipal.code)),
        //     ]);
        //     installationId = frontendId; // hack
        //     packageName = "icpack";
        //     packageVersion = "0.0.1"; // TODO: Should be `"stable"`.
        //     pmPrincipal = null;
        //     repo;
        //     user = caller;
        //     preinstalledModules = []; // FIXME
        //     bootstrappingPM = true; // FIXME: correct?
        // });
        // Don't install package here, because we don't have where to register it.
        {/*FIXME: installationId*/installationId = 0; frontendId};
    };

    // FIXME: correct indirect_caller here and in the callback?
    public shared({caller}) func bootstrapBackend(frontend: Principal, repo: Principal)
        : async {installationId: Common.InstallationId; backendId: Nat}
    {
        let backendId = nextBootstrapId;
        nextBootstrapId += 1;

        // FIXME
        // let backendPrincipal = getOurModules().pmBackendModule;
        // let indirectPrincipal = getOurModules().pmIndirectCallerModule;
        // // TODO: Allow to install only once.
        // // PM backend. It (and frontend) will be registered as an (unnamed) module by the below called `*_init()`. // FIXME
        // let {installationId} = await* Install._installModulesGroup({
        //     indirectCaller = actor(Principal.toText(Principal.fromActor(bootstrapperIndirectCaller))); // TODO: why so complex?
        //     whatToInstall = #bootstrap([
        //         ("backend", Common.extractModuleUploadBlob(backendPrincipal)),
        //         ("indirect", Common.extractModuleUploadBlob(indirectPrincipal)),
        //     ]);
        //     installationId = backendId; // hack
        //     packageName = "icpack";
        //     packageVersion = "0.0.1"; // TODO: Should be `"stable"`.
        //     pmPrincipal = null;
        //     repo;
        //     user = caller;
        //     preinstalledModules = []; // FIXME
        //     bootstrappingPM = true; // FIXME: correct?
        // });
        {/*FIXME: installationId*/installationId = 0; backendId};
    };

    // FIXME
    public shared({caller}) func bootstrapBackendCallback1({
        createdCanister: Principal;
        indirectCaller: IndirectCaller.IndirectCaller;
        installationId: Common.InstallationId;
        packageManagerOrBootstrapper: Principal;
        data: Blob;
    }): async () {
        Debug.print("Call bootstrapBackendCallback1"); // FIXME: Remove.
        if (caller != Principal.fromActor(indirectCaller)) { // TODO
            Debug.trap("bootstrapBackendCallback1: callback only from indirect_caller");
        };

        let ?d: ?{backendId: Nat; frontend: Principal; repo: Principal} = from_candid(data) else { // TODO: needed?
            Debug.trap("programming error: can't extract in bootstrapBackendCallback1");
        };

        let pm: PackageManager.PackageManager = actor(Principal.toText(createdCanister));
        // await pm.setIndirectCaller(indirect_caller_v); // set by *_init()
        await pm.setIndirectCaller(indirectCaller);
        await indirectCaller.setOwner(createdCanister);

        // FIXME: Unomment.
        // ignore await pm.installPackageWithPreinstalledModules({ // FIXME: `install_code` for `pm` may be not run yet.
        //     packageName = "icpack";
        //     version = "0.0.1"; // TODO: should be `"stable"`
        //     preinstalledModules = [("frontend", d.frontend)];
        //     repo = actor(Principal.toText(d.repo)) : Common.RepositoryPartitionRO; // TODO: inefficient
        //     caller;
        //     installationId;
        //     postInstallCallback = ?bootstrapBackendFinishCallback;
        //     data;
        // });

        // await pm.setOwner(caller); // TODO: Uncomment.
        bootstrapIds.put(d.backendId, createdCanister); // TODO: Should move up in the source?
    };

    // FIXME: I have a contradiction here: it needs `createdCanister` but
    //        `installPackageWithPreinstalledModules` may create several modules.
    // FIXME: Move `registerNamedModule`s to the correct place in the code.
    // FIXME
    public shared({caller}) func bootstrapBackendFinishCallback({
        installationId: Common.InstallationId;
        createdCanister: Principal;
        indirectCaller: IndirectCaller.IndirectCaller;
        package: Common.SharedPackageInfo;
        // caller: Principal; // TODO
        data: Blob;
    }): async () {
        if (caller != Principal.fromActor(indirectCaller)) {
            Debug.trap("bootstrapBackendFinishCallback: callback only from indirect_caller");
        };

        let pm: PackageManager.PackageManager = actor(Principal.toText(createdCanister));
        // FIXME: Uncomment.
        // await pm.registerNamedModule({
        //     installation = installationId;
        //     canister = Principal.fromActor(indirectCaller);
        //     packageManager = createdCanister;
        //     moduleName = "indirect"; // TODO: a better name?
        // });
        // // FIXME: Isn't `update_settings` unsafe? https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553/9
        // await ic.update_settings({canister_id = Principal.fromActor(indirectCaller); sender_canister_version = null; settings = {
        //     controllers = ?[createdCanister, Principal.fromActor(indirectCaller)];
        //     freezing_threshold = null;
        //     memory_allocation = null;
        //     compute_allocation = null;
        //     reserved_cycles_limit = null;
        // }});
        // await pm.registerNamedModule({ // PM backend registers itself.
        //     installation = installationId;
        //     canister = createdCanister;
        //     packageManager = createdCanister;
        //     moduleName = "backend";
        // });
        // // FIXME: Isn't `update_settings` unsafe? https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553/9
        // await ic.update_settings({canister_id = createdCanister; sender_canister_version = null; settings = {
        //     controllers = ?[createdCanister, caller]; // self-controlled // FIXME: It seems to be a wrong `caller`.
        //     freezing_threshold = null;
        //     memory_allocation = null;
        //     compute_allocation = null;
        //     reserved_cycles_limit = null;
        // }});
        // await pm.setOwner(caller); // FIXME: Put the correct `caller` (`user` instead).
    };

    // TODO: HACK
    public shared func createInstallation(): async Common.InstallationId { 0 };
}