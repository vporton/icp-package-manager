/// FIXME: Remove this in regard of init() function?
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import RepositoryPartition "RepositoryPartition";
import package_manager "package_manager";
import RepositoryIndex "RepositoryIndex";

shared({caller = originalOwner}) actor class Bootstrap() {
    stable var owner = originalOwner;

    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("not an owner");
        }
    };

    public query func getOwner(): async Principal {
        owner;
    };

    public shared({caller}) func setOwner(): async () {
        onlyOwner(caller);
        owner := caller;
    };

    stable var modules: [Blob] = [];

    public query func getWasmsCount(): async Nat {
        Array.size(modules);
    };

    public query func getWasm(index: Nat): async Blob {
        modules[index];
    };

    /// The last should be the frontend WASM.
    public shared({caller}) func setWasms(newWasms: [Blob]): async () {
        onlyOwner(caller);
        modules := newWasms;
    };

    public shared({caller}) func bootstrap(repo: Principal) {
        let canisters = Array.tabulate(Array.size(modules), func (i: Nat): Principal = Principal.fromText("aaaaa-aa"));
        for (wasmModuleLocation in modules.vals()) {
            // TODO: cycles (and monetization)
            Cycles.add<system>(10_000_000_000_000);
            let {canister_id} = await IC.create_canister({
                settings = ?{
                    freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                    controllers = ?[Principal.fromActor(indirectCaller)]; // No package manager as a controller, because the PM may be upgraded.
                    compute_allocation = null; // TODO
                    memory_allocation = null; // TODO (a low priority task)
                }
            });
            let wasmModuleSourcePartition: RepositoryPartition.RepositoryPartition =
                actor(Principal.toText(wasmModuleLocation.0));
            let ?(#blob wasm_module) =
                await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
            else {
                Debug.trap("package WASM code is not available");
            };
            let installArg = to_candid({}); // FIXME
            indirectCaller.callAllOneWay([
                {
                    canister = Principal.fromActor(IC);
                    name = "install_code";
                    data = to_candid({
                        arg = Blob.toArray(installArg); // FIXME: here and in other places: must install() be no-arguments?
                        wasm_module;
                        mode = #install;
                        canister_id;
                    });
                },
            ]);
            canisters.add(canister_id);
        };
    };

    let pm: package_manager.package_manager = actor(canisters[0]);
    let repoObj: RepositoryIndex.RepositoryIndex = actor(Principal.toText(repo)); // TODO: Can we instead pass `repoObj` directly?
    let mains = await repoObj.getCanistersByPK("main");
    pm.init(mains[0], "0.0.1", modules); // FIXME: `mains[0]` may be wrong // TODO: other versions
}