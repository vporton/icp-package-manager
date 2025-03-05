import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
// import StableHashMap "mo:stablehashmap/FunctionalStableHashMap";
import CyclesSimple "../lib/battery";

shared({caller = initialOwner}) actor class Battery({
    packageManagerOrBootstrapper: Principal;
    mainIndirect: Principal;
    simpleIndirect: Principal;
    user: Principal;
    installationId = _: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (mainIndirect, ()), // temporary
                (simpleIndirect, ()), // TODO: superfluous?
                (Principal.fromActor(this), ()), // TODO: Is it really needed to execute the timer?
                (user, ()),
            ].vals(), // TODO: Are all required?
            4,
            Principal.equal,
            Principal.hash);

    func checkCaller(caller: Principal) {
        if (Option.isNull(owners.get(caller))) {
            Debug.trap("battery: not allowed");
        }
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

    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
    };

    stable var initialized = false;

    public shared({caller}) func init() : async () {
        checkCaller(caller);
        if (initialized) {
            Debug.trap("already initialized");
        };

        owners := _owners;

        initTimer<system>();

        initialized := true;
    };

    public type ModuleLocation = {
        package: {
            packageName: Text;
            guid: Blob;
        };
        moduleName: Text;
    };

    private func compareModuleLocation(a: ModuleLocation, b: ModuleLocation): {#less; #equal; #greater;} {
        switch (Text.compare(a.package.packageName, b.package.packageName)) {
        case (#less) {
            #less;
        };
        case (#equal) {
            switch (Blob.compare(a.package.guid, b.package.guid)) {
            case (#less) {
                #less;
            };
            case (#equal) {
                Text.compare(a.moduleName, b.moduleName);
            };
            case (#greater) {
                #greater;
            };
            };
        };
        case (#greater) {
            #greater;
        };
        };
    };

    public type CanisterKind = Text;

    public let moduleLocationMap = Map.Make<ModuleLocation>(compareModuleLocation);
    public type CanisterMap = Map.Map<ModuleLocation, CanisterKind>;

    public let textMap = Map.Make<Text>(Text.compare);
    public type CanisterKindsMap = Map.Map<CanisterKind, Common.CanisterFulfillment>;

    public type Battery = {
        defaultFulfillment: Common.CanisterFulfillment;
        canisterMap: CanisterMap;
        canisterKindsMap: CanisterKindsMap;
    };

    public func newBattery(): Battery =
        {
            defaultFulfillment = {
                threshold = 3_000_000_000_000;
                installAmount = 2_000_000_000_000;
            };
            canisterMap = moduleLocationMap.empty<CanisterKind>();
            canisterKindsMap = textMap.empty<Common.CanisterFulfillment>();
        };

    public func topUpAllCanisters(battery: Battery): async* () {
        for (canisterId in OrderedMap.keys(battery.canisterMap)) {
            await* topUpOneCanister(battery, canisterId);
        };
    };

    public func addCanister(battery: Battery, canisterId: Principal, kind: Text) {
        OrderedMap.put(battery.canisterMap, Principal.equal, Principal.hash, canisterId, kind);
    };

    public func insertCanisterKind(battery: Battery, kind: Text, info: Common.CanisterFulfillment) {
        OrderedMap.put(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind, info);
    };

    func initTimer<system>() {
        timer := ?(Timer.recurringTimer<system>(#seconds 3600, topUpAllCanisters)); // TODO: editable period
    };

    stable let battery = CyclesSimple.newBattery();

    stable var timer: ?Timer.TimerId = null;

    private func topUpOneCanister(canister: ModuleLocation): async* () {
        let info0 = do ? {
            let kind = moduleLocationMap.get(battery.canisterMap, canister)!;
            textMap.get(battery.canisterKindsMap, kind)!;
        };
        let ?fulfillment = switch (info0) {
            case (?x) {
                x;
            };
            case (null) {
                battery.defaultFulfillment;
            };
        };
        getMainIndirect().topUpOneCanisterFinish(canister_id, fulfillment);
    };

    private func topUpAllCanisters(): async () {
        for ((name, m) in await getPM().getAllCanisters()) {
            await* CyclesSimple.topUpAllCanisters(battery);
        };
    };

    system func inspect({
        caller : Principal;
    }): Bool {
        checkCaller(caller);
        true;
    };

    system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());
    };

    system func postupgrade() {
        initTimer<system>();

        owners := HashMap.fromIter(
            _ownersSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _ownersSave := []; // Free memory.
    };
}