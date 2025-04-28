import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Map "mo:base/OrderedMap";
import Set "mo:base/OrderedSet";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Cycles "mo:base/ExperimentalCycles";
import LIB "mo:icpack-lib";
import Common "../common";
import MainIndirect "main_indirect";
import CyclesLedger "canister:cycles_ledger";
import env "mo:env";

shared({caller = initialOwner}) actor class Battery({
    packageManager: Principal; // may be the bootstrapper instead.
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
                (packageManager, ()),
                (mainIndirect, ()), // temporary
                (simpleIndirect, ()),
                (Principal.fromActor(this), ()), // to execute the timer
                (user, ()),
            ].vals(),
            5,
            Principal.equal,
            Principal.hash);

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        };
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
        onlyOwner(caller, "init");
        if (initialized) {
            Debug.trap("already initialized");
        };

        await* addWithdrawer(mainIndirect);
        await* addWithdrawer(packageManager);

        initTimer<system>();

        initialized := true;
    };

    public query func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async () {
        if (not initialized) {
            Debug.trap("battery: not initialized");
        };
    };

    let revenueRecipient = Principal.fromText(env.revenueRecipient);

    private type OurPMType = actor {
        // getModulePrincipal: query (installationId: Common.InstallationId, moduleName: Text) -> async Principal;
        getAllCanisters: query () -> async [({packageName: Text; guid: Blob}, [(Text, Principal)])];
    };

    private func getPM(): OurPMType {
        actor(Principal.toText(packageManager));
    };

    private func getMainIndirect(): MainIndirect.MainIndirect {
        actor(Principal.toText(mainIndirect));
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

    let moduleLocationMap = Map.Make<ModuleLocation>(compareModuleLocation);
    public type CanisterMap = Map.Map<ModuleLocation, CanisterKind>;

    let textMap = Map.Make<Text>(Text.compare);
    public type CanisterKindsMap = Map.Map<CanisterKind, Common.CanisterFulfillment>;

    public type Battery = {
        canisterInitialCycles: Nat;
        defaultFulfillment: Common.CanisterFulfillment;
        canisterMap: CanisterMap;
        canisterKindsMap: CanisterKindsMap;
        /// The number of cycles from which the fee has been already paid.
        var activatedCycles: Nat;
    };

    private func newBattery(): Battery =
        {
            canisterInitialCycles = 1_000_000_000_000;
            defaultFulfillment = {
                threshold = 3_000_000_000_000;
                topupAmount = 2_000_000_000_000;
            };
            canisterMap = moduleLocationMap.empty<CanisterKind>();
            canisterKindsMap = textMap.empty<Common.CanisterFulfillment>();
            var activatedCycles = 0;
        };

    public query func getCanisterInitialCycles(): async Nat {
        // onlyOwner(caller, "setDefaultFulfillment");

        battery.canisterInitialCycles;
    };

    // TODO@P3:
    // public func insertCanisterKind(battery: Battery, kind: Text, info: Common.CanisterFulfillment) {
    //     OrderedMap.put(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind, info);
    // };

    func initTimer<system>() {
        timer := ?(Timer.recurringTimer<system>(#seconds 3600, topUpAllCanisters)); // TODO@P3: editable period
    };

    stable let battery = newBattery();

    stable var timer: ?Timer.TimerId = null;

    private func topUpOneCanister(canister: ModuleLocation, canister_id: Principal): async* () {
        let info0 = do ? {
            let kind = moduleLocationMap.get(battery.canisterMap, canister)!;
            textMap.get(battery.canisterKindsMap, kind)!;
        };
        let fulfillment = switch (info0) {
            case (?x) x;
            case null battery.defaultFulfillment;
        };
        Cycles.add<system>(fulfillment.topupAmount); // TODO@P3: If this traps on a too high amount, keep filling other canisters?
        getMainIndirect().topUpOneCanisterFinish(canister_id, fulfillment);
    };

    private func topUpAllCanisters(): async () {
        let newCycles = Int.abs(+Cycles.balance() - battery.activatedCycles);
        if (newCycles != 0) {
            // let fee = Float.toInt(Float.fromInt(newCycles) * 0.05); // 5%
            let fee = newCycles / 20; // 5%
            let res = await CyclesLedger.icrc1_transfer({
                to = {owner = revenueRecipient; subaccount = null};
                fee = null;
                memo = null;
                from_subaccount = null; // {owner = revenueRecipient; subaccount = ?null};
                created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
                amount = fee;
            });
            switch (res) {
                case (#Err err) {
                    Debug.trap("cannot transfer fee: " # debug_show(err));
                };
                case (#Ok _) {};
            };
            battery.activatedCycles += newCycles - fee;
        };

        let allCanisters = await getPM().getAllCanisters();
        
        for (entry in allCanisters.vals()) {
            let pkg = entry.0;
            let modules = entry.1;
            
            for (moduleEntry in modules.vals()) {
                let moduleName = moduleEntry.0;
                let canister_id = moduleEntry.1;
                
                let location: ModuleLocation = {
                    package = {
                        packageName = pkg.packageName;
                        guid = pkg.guid;
                    };
                    moduleName = moduleName;
                };
                
                await* topUpOneCanister(location, canister_id);
            };
        };
    };

    let principalSet = Set.Make<Principal>(Principal.compare);
    var withdrawers = principalSet.empty();

    /// TODO@P3: Make it editable using user confirmation.
    private func addWithdrawer(withdrawer: Principal): async* () {
        withdrawers := principalSet.put(withdrawers, withdrawer);
    };

    public shared func withdrawCycles(amount: Nat, payee: Principal) : async () {
        await* LIB.withdrawCycles(CyclesLedger, amount, payee);
    };

    public shared func withdrawCycles2(amount: Nat, payee: Principal) : async () {
        if (not principalSet.contains(withdrawers, payee)) {
            Debug.trap("withdrawCycles2: payee is not a controller");
        };
        switch (await CyclesLedger.icrc1_transfer({
            to = {owner = payee; subaccount = null};
            amount;
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
        })) {
            case (#Err e) {
                Debug.trap("withdrawCycles: " # debug_show(e));
            };
            case (#Ok _) {};
        };
    };

    system func inspect({
        caller : Principal;
    }): Bool {
        onlyOwner(caller, "inspect"/*TODO@P3*/);
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