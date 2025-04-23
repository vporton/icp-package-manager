import ICE "mo:base/ExperimentalInternetComputer";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import IC "mo:ic";
import Common "../common";

shared({caller = initialCaller}) actor class SimpleIndirect({
    packageManager: Principal; // may be the bootstrapper instead.
    mainIndirect: Principal;
    simpleIndirect: Principal;
    user: Principal;
    installationId: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // let ?userArgValue: ?{
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    stable var initialized = false;

    // stable var _ownersSave: [(Principal, ())] = []; // We don't ugrade this package
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManager, ()),
                (mainIndirect, ()),
                (user, ()),
                (simpleIndirect, ()),
            ].vals(),
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({ // TODO@P3
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManager: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installModule`. // TODO@P3: needed here?

        type OurPMType = actor {
            getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
        };
        let pm: OurPMType = actor (Principal.toText(packageManager));
        let battery = await pm.getModulePrincipal(installationId, "battery");
        owners.put(battery, ());

        initialized := true;
    };

    public query func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async () {
        if (not initialized) {
            Debug.trap("simple_indirect: not initialized");
        };
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
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

    public type OnError = { #abort; #keepDoing };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    ///
    /// TODO@P3: It would be more efficient and elegant to pass a shared method.
    private func callAllImpl(methods: [{canister: Principal; name: Text; data: Blob; error: OnError}]): async* () {
        label cycle for (method in methods.vals()) {
            try {
                ignore await ICE.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                if (method.error == #abort or Error.code(e) == #call_error {err_code = 302}) { // CanisterMethodNotFound
                    Debug.trap(msg);
                };
            };
        };
    };

    public shared({caller}) func callAll(methods: [{canister: Principal; name: Text; data: Blob; error: OnError}]): async () {
        onlyOwner(caller, "callAllOneWay");

        await* callAllImpl(methods);
    };

    // TODO@P2: Are the following methods necessary? Can't we use `callAll` with management canister?

    public shared({caller}) func canister_info(args: IC.CanisterInfoArgs, amount: Nat): async IC.CanisterInfoResult {
        onlyOwner(caller, "canister_info");

        Cycles.add<system>(amount);
        await IC.ic.canister_info(args);
    };

	public shared({caller}) func canister_status(args: IC.CanisterStatusArgs, amount: Nat): async IC.CanisterStatusResult {
        onlyOwner(caller, "canister_status");

        Cycles.add<system>(amount);
        await IC.ic.canister_status(args);
    };

	public shared({caller}) func clear_chunk_store(args: IC.ClearChunkStoreArgs, amount: Nat): async () {
        onlyOwner(caller, "clear_chunk_store");

        Cycles.add<system>(amount);
        await IC.ic.clear_chunk_store(args);
    };

    public shared({caller}) func create_canister(args: IC.CreateCanisterArgs, amount: Nat): async IC.CreateCanisterResult {
        onlyOwner(caller, "create_canister");

        Cycles.add<system>(amount);
        await IC.ic.create_canister(args);
    };

	public shared({caller}) func delete_canister(args: IC.DeleteCanisterArgs, amount: Nat): async () {
        onlyOwner(caller, "delete_canister");

        Cycles.add<system>(amount);
        await IC.ic.delete_canister(args);
    };

	public shared({caller}) func delete_canister_snapshot(args: IC.DeleteCanisterSnapshotArgs, amount: Nat): async () {
        onlyOwner(caller, "delete_canister_snapshot");

        Cycles.add<system>(amount);
        await IC.ic.delete_canister_snapshot(args);
    };

	public shared({caller}) func deposit_cycles(args: IC.DepositCyclesArgs, amount: Nat): async () {
        onlyOwner(caller, "deposit_cycles");

        Cycles.add<system>(amount);
        await IC.ic.deposit_cycles(args);
    };

    public shared({caller}) func ecdsa_public_key(args: IC.EcdsaPublicKeyArgs, amount: Nat): async IC.EcdsaPublicKeyResult {
        onlyOwner(caller, "ecdsa_public_key");

        Cycles.add<system>(amount);
        await IC.ic.ecdsa_public_key(args);
    };

    public composite query({caller}) func fetch_canister_logs(args: IC.FetchCanisterLogsArgs): async IC.FetchCanisterLogsResult {
        onlyOwner(caller, "fetch_canister_logs");

        // Cycles.add<system>(amount);
        await IC.ic.fetch_canister_logs(args);
    };

    public shared({caller}) func http_request(args: IC.HttpRequestArgs, amount: Nat): async IC.HttpRequestResult {
        onlyOwner(caller, "http_request");

        Cycles.add<system>(amount);
        await IC.ic.http_request(args);
    };

	public shared({caller}) func install_chunked_code(args: IC.InstallChunkedCodeArgs, amount: Nat): async () {
        onlyOwner(caller, "install_chunked_code");

        Cycles.add<system>(amount);
        await IC.ic.install_chunked_code(args);
    };

	public shared({caller}) func install_code(args: IC.InstallCodeArgs, amount: Nat): async () {
        onlyOwner(caller, "install_code");

        Cycles.add<system>(amount);
        await IC.ic.install_code(args);
    };

	public shared({caller}) func list_canister_snapshots(args: IC.ListCanisterSnapshotsArgs, amount: Nat): async IC.ListCanisterSnapshotsResult {
        onlyOwner(caller, "list_canister_snapshots");

        Cycles.add<system>(amount);
        await IC.ic.list_canister_snapshots(args);
    };

	public shared({caller}) func load_canister_snapshot(args: IC.LoadCanisterSnapshotArgs, amount: Nat): async () {
        onlyOwner(caller, "load_canister_snapshot");

        Cycles.add<system>(amount);
        await IC.ic.load_canister_snapshot(args);
    };

	public shared({caller}) func node_metrics_history(args: IC.NodeMetricsHistoryArgs, amount: Nat): async IC.NodeMetricsHistoryResult {
        onlyOwner(caller, "node_metrics_history");

        Cycles.add<system>(amount);
        await IC.ic.node_metrics_history(args);
    };

	public shared({caller}) func provisional_create_canister_with_cycles(args: IC.ProvisionalCreateCanisterWithCyclesArgs, amount: Nat): async IC.ProvisionalCreateCanisterWithCyclesResult {
        onlyOwner(caller, "provisional_create_canister_with_cycles");

        Cycles.add<system>(amount);
        await IC.ic.provisional_create_canister_with_cycles(args);
    };

	public shared({caller}) func provisional_top_up_canister(args: IC.ProvisionalTopUpCanisterArgs, amount: Nat): async () {
        onlyOwner(caller, "provisional_top_up_canister");

        Cycles.add<system>(amount);
        await IC.ic.provisional_top_up_canister(args);
    };

	public shared({caller}) func raw_rand(amount: Nat): async IC.RawRandResult {
        onlyOwner(caller, "raw_rand");

        Cycles.add<system>(amount);
        await IC.ic.raw_rand();
    };

    public shared({caller}) func schnorr_public_key(args: IC.SchnorrPublicKeyArgs, amount: Nat): async IC.SchnorrPublicKeyResult {
        onlyOwner(caller, "schnorr_public_key");

        Cycles.add<system>(amount);
        await IC.ic.schnorr_public_key(args);
    };

    public shared({caller}) func sign_with_ecdsa(args: IC.SignWithEcdsaArgs, amount: Nat): async IC.SignWithEcdsaResult {
        onlyOwner(caller, "sign_with_ecdsa");

        Cycles.add<system>(amount);
        await IC.ic.sign_with_ecdsa(args);
    };

    public shared({caller}) func sign_with_schnorr(args: IC.SignWithSchnorrArgs, amount: Nat): async IC.SignWithSchnorrResult {
        onlyOwner(caller, "sign_with_schnorr");

        Cycles.add<system>(amount);
        await IC.ic.sign_with_schnorr(args);
    };

	public shared({caller}) func start_canister(args: IC.StartCanisterArgs, amount: Nat): async () {
        onlyOwner(caller, "start_canister");

        Cycles.add<system>(amount);
        await IC.ic.start_canister(args);
    };

	public shared({caller}) func stop_canister(args: IC.StopCanisterArgs, amount: Nat): async () {
        onlyOwner(caller, "stop_canister");

        Cycles.add<system>(amount);
        await IC.ic.stop_canister(args);
    };

	public shared({caller}) func stored_chunks(args: IC.StoredChunksArgs, amount: Nat): async IC.StoredChunksResult {
        onlyOwner(caller, "stored_chunks");

        Cycles.add<system>(amount);
        await IC.ic.stored_chunks(args);
    };

	public shared({caller}) func take_canister_snapshot(args: IC.TakeCanisterSnapshotArgs, amount: Nat): async IC.TakeCanisterSnapshotResult {
        onlyOwner(caller, "take_canister_snapshot");

        Cycles.add<system>(amount);
        await IC.ic.take_canister_snapshot(args);
    };

	public shared({caller}) func uninstall_code(args: IC.uninstall_code_args, amount: Nat): async () {
        onlyOwner(caller, "uninstall_code");

        Cycles.add<system>(amount);
        await IC.ic.uninstall_code(args);
    };

	public shared({caller}) func update_settings(args: IC.UpdateSettingsArgs, amount: Nat): async () {
        onlyOwner(caller, "update_settings");

        Cycles.add<system>(amount);
        await IC.ic.update_settings(args);
    };

	public shared({caller}) func upload_chunk(args: IC.UploadChunkArgs, amount: Nat): async IC.UploadChunkResult {
        onlyOwner(caller, "upload_chunk");

        Cycles.add<system>(amount);
        await IC.ic.upload_chunk(args);
    };
};