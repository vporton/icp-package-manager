import HashMap "mo:base/HashMap";
import PackageManager "icp_summer_backend/package_manager";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";

import Debug "mo:base/Debug";
shared({caller}) actor class PackageManager = this {
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

    public shared func installPackage(part: RepositoryPartitionRO, packageName: PackageName, version: PackageVersion)
        : async InstallationId
    {
        let package = part.getPackage(packageName);
        let IC: CanisterCreator = actor("aaaaa-aa");

        // TODO: Don't wait for creation of a previous canister to create the next one.
        for (wasm in package.wasms) {
            await IC.create_canister({
                freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                controllers = null; // We are the controller.
                compute_allocation = null; // TODO
                memory_allocation = null; // TODO (a low priority task)
            });
        };
        //
        for (wasm in package.wasms) {
            indirect_caller.call
        }
        // TODO
    };
}}