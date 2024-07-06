import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Common "common";

shared({caller}) actor class PackageManager() = this {
    stable let owners: HashMap.HashMap<Principal, ()> = HashMap.fromIter([caller].vals());

    func onlyOwner(caller: Principal) {
        if (not owners.hasKey(caller)) {
            Debug.trap("not the owner");
        }
    };

    type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    type canister_id = Principal;
    type wasm_module = Blob;

    type CanistorCreator = actor {
        create_canister : shared { settings : ?canister_settings } -> async {
            canister_id : canister_id;
        };
        install_code : shared {
            arg : [Nat8];
            wasm_module : wasm_module;
            mode : { #reinstall; #upgrade; #install };
            canister_id : canister_id;
        } -> async ();
    };

    public shared({caller}) func installPackage({
        part: Common.RepositoryPartitionRO;
        packageName: Common.PackageName;
        version: Common.PackageVersion;
    })
        : async InstallationId
    {
        let package = part.getPackage(packageName);
        let IC: CanisterCreator = actor("aaaaa-aa");

        let canisters = Buffer.new(Array.size(package.wasms));
        // TODO: Don't wait for creation of a previous canister to create the next one.
        for (wasmModuleLocation in package.base.wasms) {
            // TODO: cycles (and monetization)
            let {canister_id} = await IC.create_canister({
                freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                controllers = null; // We are the controller.
                compute_allocation = null; // TODO
                memory_allocation = null; // TODO (a low priority task)
            });
            let wasmModuleSourcePartition: CanDBPartition = actor(wasmModuleLocation.0);
            let ?(#blob wasm_module) = wasmModuleSourcePartition.get({sk = wasmModuleLocation.1}) else {
                // TODO: Delete installed modules and start anew.
                Debug.trap("package WASM code is not available");
            };
            await IC.install_code({
                arg = to_candid({user = caller; previousCanisters = canisters; packageManager = this});
                wasm_module;
                mode = #install;
                canister_id;
            });
            canisters.add(canister_id);
        };
        indirect_caller.call(
            Iter.toArray(Iter.map(
                canisters.keys(),
                func (i) {
                    (
                        {
                            canister = canisters[i];
                            name = "init";
                            data = to_candid({
                                user = caller;
                                previousCanisters = Array.subArray(canisters, 0, i);
                                packageManager = this;
                            })
                        }
                    );
                },
            )),
        );
    };
}