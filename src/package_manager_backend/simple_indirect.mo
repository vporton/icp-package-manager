import ICE "mo:base/ExperimentalInternetComputer";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import IC "mo:ic";

shared({caller = initialCaller}) actor class SimpleIndirect({
    packageManagerOrBootstrapper: Principal;
    initialIndirect: Principal; // TODO: Rename.
    user: Principal;
    // installationId: Common.InstallationId;
    // userArg: Blob;
}) = this {
    // let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    stable var initialized = false;

    // stable var _ownersSave: [(Principal, ())] = []; // We don't ugrade this package
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (initialIndirect, ()),
                (user, ()),
            ].vals(),
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({ // TODO
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManagerOrBootstrapper: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`.

        // ourPM := actor (Principal.toText(packageManagerOrBootstrapper)): OurPMType;
        initialized := true;
    };

    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
    };

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        onlyOwner(caller, "setOwners");

        owners := HashMap.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Array.size(newOwners),
            Principal.equal,
            Principal.hash,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        onlyOwner(caller, "addOwner");

        owners.put(newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        onlyOwner(caller, "removeOwner");

        owners.delete(oldOwner);
    };

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    private func callAllOneWayImpl(methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        label cycle for (method in methods.vals()) {
            try {
                ignore await ICE.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
                break cycle;
            };
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, keep calling other methods.
    ///
    /// TODO: We don't need this function.
    private func callIgnoringMissingOneWayImpl(methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        for (method in methods.vals()) {
            try {
                ignore await ICE.call(method.canister, method.name, method.data);
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
                if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                    throw e; // Other error cause interruption.
                }
            };
        };
    };

    /// TODO: We don't need this function.
    public shared({caller}) func callIgnoringMissingOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller, "callIgnoringMissingOneWay");

        await* callIgnoringMissingOneWayImpl(methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller, "callAllOneWay");

        await* callAllOneWayImpl(methods);
    };

    /// TODO: We don't need this function.
    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller, "callIgnoringMissing");

        try {
            return await ICE.call(method.canister, method.name, method.data); 
        }
        catch (e) {
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared({caller}) func call(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller, "call");

        try {
            return await ICE.call(method.canister, method.name, method.data);
        }
        catch (e) {
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    // TODO: Are the following methods necessary? Can't we use `callAll` with management canister?

    // public shared({caller}) func canister_info(args: CanisterInfoArgs): async CanisterInfoResult {
    //     onlyOwner(caller, "call");
    // };

	// public shared({caller}) func canister_status(args: CanisterStatusArgs): async CanisterStatusResult {
    //     onlyOwner(caller, "call");
    // };

	public shared({caller}) func delete_canister(args: IC.DeleteCanisterArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.delete_canister(args);
    };

	public shared({caller}) func delete_canister_snapshot(args: IC.DeleteCanisterSnapshotArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.delete_canister_snapshot(args);
    };

    // TODO: Is `amount` needed here?
	public shared({caller}) func deposit_cycles(args: IC.DepositCyclesArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.deposit_cycles(args);
    };

	// TODO: https://forum.dfinity.org/t/can-a-query-be-dosed-by-nn-returning-function
    // public query({caller}) func fetch_canister_logs(args: FetchCanisterLogsArgs): async FetchCanisterLogsResultasync {
    //     onlyOwner(caller, "call");
    // };

	public shared({caller}) func install_chunked_code(args: IC.InstallChunkedCodeArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.install_chunked_code(args);
    };

	public shared({caller}) func install_code(args: IC.InstallCodeArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.install_code(args);
    };

	// public shared({caller}) func list_canister_snapshots(args: ListCanisterSnapshotsArgs): async ListCanisterSnapshotsResult {
    //     onlyOwner(caller, "call");
    // };

	public shared({caller}) func load_canister_snapshot(args: IC.LoadCanisterSnapshotArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.load_canister_snapshot(args);
    };

	public shared({caller}) func provisional_top_up_canister(args: IC.ProvisionalTopUpCanisterArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.provisional_top_up_canister(args);
    };

	public shared({caller}) func start_canister(args: IC.StartCanisterArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.start_canister(args);
    };

	public shared({caller}) func stop_canister(args: IC.StopCanisterArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.stop_canister(args);
    };

	// public shared({caller}) func stored_chunks(args: StoredChunksArgs): async StoredChunksResult {
    //     onlyOwner(caller, "call");
    // };

	public shared({caller}) func take_canister_snapshot(args: IC.TakeCanisterSnapshotArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        ignore await IC.ic.take_canister_snapshot(args);
    };

	public shared({caller}) func uninstall_code(args: IC.uninstall_code_args, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.uninstall_code(args);
    };

	public shared({caller}) func update_settings(args: IC.UpdateSettingsArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        await IC.ic.update_settings(args);
    };

	public shared({caller}) func upload_chunk(args: IC.UploadChunkArgs, amount: Nat): () {
        onlyOwner(caller, "call");

        Cycles.add<system>(amount);
        ignore await IC.ic.upload_chunk(args);
    };
};