import ICE "mo:core/InternetComputer"; // TODO@P3: Rename.
import Cycles "mo:core/Cycles";
import Error "mo:core/Error";
import Map "mo:core/Map";
import Principal "mo:core/Principal";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Debug "mo:core/Debug";
import Blob "mo:core/Blob";
import IC "mo:ic";
import Common "../common";
import LIB "mo:icpack-lib";
import CyclesLedger "canister:cycles_ledger";

shared({caller = initialCaller}) persistent actor class SimpleIndirect({
    packageManager: Principal; // may be the bootstrapper instead.
    mainIndirect: Principal;
    simpleIndirect: Principal;
    battery: Principal;
    user: Principal;
    installationId: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // let ?userArgValue: ?{
    // } = from_candid(userArg) else {
    //     throw Error.reject("argument userArg is wrong");
    // };

    stable var initialized = false;

    // FIXME@P1: Use `Set`.
    stable var owners: Map.Map<Principal, ()> =
        Map.fromIter(
            [
                (packageManager, ()),
                (mainIndirect, ()),
                (user, ()),
                (simpleIndirect, ()),
                (battery, ()),
            ].vals(),
            Principal.compare);

    public shared({caller}) func init({ // TODO@P3
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManager: Principal;
    }): async () {
        await* onlyOwner(caller, "init");

        ignore Map.insert<Principal, ()>(owners, Principal.compare, Principal.fromActor(this), ()); // self-usage to call `this.installModule`. // TODO@P3: needed here?

        type OurPMType = actor {
            getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
        };
        let pm: OurPMType = actor (Principal.toText(packageManager));
        let battery = await pm.getModulePrincipal(installationId, "battery");
        ignore Map.insert<Principal, ()>(owners, Principal.compare, battery, ());

        initialized := true;
    };

    public query func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async () {
        if (not initialized) {
            throw Error.reject("simple_indirect: not initialized");
        };
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(Map.keys(owners));
    };

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        await* onlyOwner(caller, "setOwners");

        owners := Map.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Principal.compare,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        await* onlyOwner(caller, "addOwner");

        ignore Map.insert<Principal, ()>(owners, Principal.compare, newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        await* onlyOwner(caller, "removeOwner");

        ignore Map.delete(owners, Principal.compare, oldOwner);
    };

    func onlyOwner(caller: Principal, msg: Text): async* () {
        if (Map.get(owners, Principal.compare, caller) == null) {
            throw Error.reject("not the owner: " # msg);
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
                    throw Error.reject(msg);
                };
            };
        };
    };

    public shared({caller}) func callAll(methods: [{canister: Principal; name: Text; data: Blob; error: OnError}]): async () {
        await* onlyOwner(caller, "callAllOneWay");

        await* callAllImpl(methods);
    };

    public shared({caller}) func canister_info(args: IC.CanisterInfoArgs, amount: Nat): async IC.CanisterInfoResult {
        await* onlyOwner(caller, "canister_info");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.canister_info(args);
        }
        catch (e) {
            let msg = "canister_info: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        };
    };

	public shared({caller}) func canister_status(args: IC.CanisterStatusArgs, amount: Nat): async IC.CanisterStatusResult {
        await* onlyOwner(caller, "canister_status");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.canister_status(args);
        }
        catch (e) {
            let msg = "canister_status: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func clear_chunk_store(args: IC.ClearChunkStoreArgs, amount: Nat): async () {
        await* onlyOwner(caller, "clear_chunk_store");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.clear_chunk_store(args);
        }
        catch (e) {
            let msg = "clear_chunk_store: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func create_canister(args: IC.CreateCanisterArgs, amount: Nat): async IC.CreateCanisterResult {
        await* onlyOwner(caller, "create_canister");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.create_canister(args);
        }
        catch (e) {
            let msg = "create_canister: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func delete_canister(args: IC.DeleteCanisterArgs, amount: Nat): async () {
        await* onlyOwner(caller, "delete_canister");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.delete_canister(args);
        }
        catch (e) {
            let msg = "delete_canister: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func delete_canister_snapshot(args: IC.DeleteCanisterSnapshotArgs, amount: Nat): async () {
        await* onlyOwner(caller, "delete_canister_snapshot");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.delete_canister_snapshot(args);
        }
        catch (e) {
            let msg = "delete_canister_snapshot: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func deposit_cycles(args: IC.DepositCyclesArgs, amount: Nat): async () {
        await* onlyOwner(caller, "deposit_cycles");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.deposit_cycles(args);
        }
        catch (e) {
            let msg = "deposit_cycles: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func ecdsa_public_key(args: IC.EcdsaPublicKeyArgs, amount: Nat): async IC.EcdsaPublicKeyResult {
        await* onlyOwner(caller, "ecdsa_public_key");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.ecdsa_public_key(args);
        }
        catch (e) {
            let msg = "ecdsa_public_key: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public composite query({caller}) func fetch_canister_logs(args: IC.FetchCanisterLogsArgs): async IC.FetchCanisterLogsResult {
        // TODO@P2: duplicate code
        if (Map.get(owners, Principal.compare, caller) == null) {
            throw Error.reject("not the owner: " # "fetch_canister_logs");
        };

        try {
            await IC.ic.fetch_canister_logs(args);
        }
        catch (e) {
            let msg = "fetch_canister_logs: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func http_request(args: IC.HttpRequestArgs, amount: Nat): async IC.HttpRequestResult {
        await* onlyOwner(caller, "http_request");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.http_request(args);
        }
        catch (e) {
            let msg = "http_request: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func install_chunked_code(args: IC.InstallChunkedCodeArgs, amount: Nat): async () {
        await* onlyOwner(caller, "install_chunked_code");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.install_chunked_code(args);
        }
        catch (e) {
            let msg = "install_chunked_code: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func install_code(args: IC.InstallCodeArgs, amount: Nat): async () {
        await* onlyOwner(caller, "install_code");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.install_code(args);
        }
        catch (e) {
            let msg = "install_code: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func list_canister_snapshots(args: IC.ListCanisterSnapshotsArgs, amount: Nat): async IC.ListCanisterSnapshotsResult {
        await* onlyOwner(caller, "list_canister_snapshots");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.list_canister_snapshots(args);
        }
        catch (e) {
            let msg = "list_canister_snapshots: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func load_canister_snapshot(args: IC.LoadCanisterSnapshotArgs, amount: Nat): async () {
        await* onlyOwner(caller, "load_canister_snapshot");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.load_canister_snapshot(args);
        }
        catch (e) {
            let msg = "load_canister_snapshot: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func node_metrics_history(args: IC.NodeMetricsHistoryArgs, amount: Nat): async IC.NodeMetricsHistoryResult {
        await* onlyOwner(caller, "node_metrics_history");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.node_metrics_history(args);
        }
        catch (e) {
            let msg = "node_metrics_history: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func provisional_create_canister_with_cycles(args: IC.ProvisionalCreateCanisterWithCyclesArgs, amount: Nat): async IC.ProvisionalCreateCanisterWithCyclesResult {
        await* onlyOwner(caller, "provisional_create_canister_with_cycles");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.provisional_create_canister_with_cycles(args);
        }
        catch (e) {
            let msg = "provisional_create_canister_with_cycles: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func provisional_top_up_canister(args: IC.ProvisionalTopUpCanisterArgs, amount: Nat): async () {
        await* onlyOwner(caller, "provisional_top_up_canister");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.provisional_top_up_canister(args);
        }
        catch (e) {
            let msg = "provisional_top_up_canister: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func raw_rand(amount: Nat): async IC.RawRandResult {
        await* onlyOwner(caller, "raw_rand");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.raw_rand();
        }
        catch (e) {
            let msg = "raw_rand: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func schnorr_public_key(args: IC.SchnorrPublicKeyArgs, amount: Nat): async IC.SchnorrPublicKeyResult {
        await* onlyOwner(caller, "schnorr_public_key");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.schnorr_public_key(args);
        }
        catch (e) {
            let msg = "schnorr_public_key: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func sign_with_ecdsa(args: IC.SignWithEcdsaArgs, amount: Nat): async IC.SignWithEcdsaResult {
        await* onlyOwner(caller, "sign_with_ecdsa");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.sign_with_ecdsa(args);
        }
        catch (e) {
            let msg = "sign_with_ecdsa: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func sign_with_schnorr(args: IC.SignWithSchnorrArgs, amount: Nat): async IC.SignWithSchnorrResult {
        await* onlyOwner(caller, "sign_with_schnorr");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.sign_with_schnorr(args);
        }
        catch (e) {
            let msg = "sign_with_schnorr: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func start_canister(args: IC.StartCanisterArgs, amount: Nat): async () {
        await* onlyOwner(caller, "start_canister");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.start_canister(args);
        }
        catch (e) {
            let msg = "start_canister: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func stop_canister(args: IC.StopCanisterArgs, amount: Nat): async () {
        await* onlyOwner(caller, "stop_canister");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.stop_canister(args);
        }
        catch (e) {
            let msg = "stop_canister: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func stored_chunks(args: IC.StoredChunksArgs, amount: Nat): async IC.StoredChunksResult {
        await* onlyOwner(caller, "stored_chunks");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.stored_chunks(args);
        }
        catch (e) {
            let msg = "stored_chunks: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func take_canister_snapshot(args: IC.TakeCanisterSnapshotArgs, amount: Nat): async IC.TakeCanisterSnapshotResult {
        await* onlyOwner(caller, "take_canister_snapshot");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.take_canister_snapshot(args);
        }
        catch (e) {
            let msg = "take_canister_snapshot: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func uninstall_code(args: IC.uninstall_code_args, amount: Nat): async () {
        await* onlyOwner(caller, "uninstall_code");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.uninstall_code(args);
        }
        catch (e) {
            let msg = "uninstall_code: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func update_settings(args: IC.UpdateSettingsArgs, amount: Nat): async () {
        await* onlyOwner(caller, "update_settings");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.update_settings(args);
        }
        catch (e) {
            let msg = "update_settings: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

	public shared({caller}) func upload_chunk(args: IC.UploadChunkArgs, amount: Nat): async IC.UploadChunkResult {
        await* onlyOwner(caller, "upload_chunk");

        try {
            ignore Cycles.accept<system>(amount);
            await (with cycles = amount) IC.ic.upload_chunk(args);
        }
        catch (e) {
            let msg = "upload_chunk: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };

    public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
        try {
            await* LIB.withdrawCycles(CyclesLedger, amount, payee, caller);
        }
        catch (e) {
            let msg = "withdrawCycles: " # Error.message(e);
            Debug.print(msg);
            throw Error.reject(msg);
        }
    };
};