/// Battery canister or battery module is a canister that holds cycles and delivers them to other canisters.
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
import Cycles "mo:base/ExperimentalCycles";
import Float "mo:base/Float";
import Common "../common";
import IC "mo:ic";
import LIB "mo:icpack-lib";
import Nat64 "mo:base/Nat64";
import ICPLedger "canister:nns-ledger";
import CyclesLedger "canister:cycles_ledger";
import CMC "canister:nns-cycles-minting";
import BootstrapperData "canister:bootstrapper_data";
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
            canisterInitialCycles = 1_500_000_000_000;
            defaultFulfillment = {
                threshold = 800_000_000_000;
                topupAmount = 500_000_000_000;
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
        let mainIndirectActor = actor(Principal.toText(mainIndirect)) : actor {
            topUpOneCanisterFinish: shared (canister_id: Principal, fulfillment: Common.CanisterFulfillment) -> async ();
        };
        ignore mainIndirectActor.topUpOneCanisterFinish(canister_id, fulfillment);
    };

    private func topUpAllCanisters(): async () {
        let newCycles = Int.abs(+Cycles.balance() - battery.activatedCycles);
        if (newCycles != 0) {
            // let fee = Float.toInt(Float.fromInt(newCycles) * 0.05); // 5%
            let fee = newCycles / 20; // 5% // TODO@P2: duplicate code
            let res2 = await CyclesLedger.icrc1_transfer({
                to = {owner = revenueRecipient; subaccount = null};
                fee = null;
                memo = null;
                from_subaccount = ?(Blob.toArray(Common.principalToSubaccount(user)));
                created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
                amount = fee - Common.cycles_transfer_fee;
            });
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
    private func addWithdrawer(withdrawer: Principal) {
        withdrawers := principalSet.put(withdrawers, withdrawer);
    };

    addWithdrawer(mainIndirect);
    addWithdrawer(packageManager);

    public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
        await* LIB.withdrawCycles(/*CyclesLedger,*/ amount, payee, caller);
    };

    /// TODO@P3: Unused function.
    // public shared({caller}) func withdrawCycles2(amount: Nat, payee: Principal) : async () {
    //     if (not principalSet.contains(withdrawers, caller)) {
    //         Debug.trap("withdrawCycles2: caller is not allowed");
    //     };
    //     switch (await CyclesLedger.icrc1_transfer({
    //         to = {owner = payee; subaccount = null};
    //         amount = amount - Common.cycles_transfer_fee; // TODO@P3: Does it account for `cycles_transfer_fee` twice?
    //         fee = null;
    //         memo = null;
    //         from_subaccount = null;
    //         created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
    //     })) {
    //         case (#Err e) {
    //             Debug.trap("withdrawCycles: " # debug_show(e));
    //         };
    //         case (#Ok _) {
    //             Debug.print("Withdraw cycles from battery: " # debug_show(amount));
    //         };
    //     };
    // };

    public shared({caller}) func withdrawCycles3(amount: Nat, payee: Principal) : async () {
        if (not Principal.isController(caller)) { // important to use controllers not owners, for this to be initialized during bootstrapping
            Debug.trap("withdrawCycles3: caller is not allowed");
        };
        if (Cycles.balance() < amount) {
            Debug.trap("not enough cycles");
        };
        Cycles.add<system>(amount);
        await IC.ic.deposit_cycles({canister_id = payee});
    };

    public shared({caller}) func withdrawCycles4(amount: Nat) : async () {
        if (not Principal.isController(caller)) {
            Debug.trap("withdrawCycles4: caller is not allowed");
        };
        Cycles.add<system>(amount);
        await IC.ic.deposit_cycles({canister_id = caller});
    };

    public shared({caller}) func topUpCycles() {
        onlyOwner(caller, "topUpCycles");

        let balance = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = null;
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(balance) * env.revenueShare));
        let res2 = await CyclesLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Blob.toArray(Common.principalToSubaccount(user)));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.cycles_transfer_fee;
        });
        let #Ok tx = res2 else {
            Debug.trap("transfer failed: " # debug_show(res2));
        };

        let res = await CyclesLedger.withdraw({
            amount = balance - revenue - Common.cycles_transfer_fee;
            from_subaccount = null;
            to = Principal.fromActor(this);
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
        });
        let #Ok _ = res else {
            Debug.trap("transfer failed: " # debug_show(res));
        };
    };

    public shared({caller = user}) func topUpWithICP(): async {balance: Nat} {
        let icpBalance = await ICPLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = null;
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(icpBalance) * env.revenueShare));
        let res2 = await ICPLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Common.principalToSubaccount(user));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.icp_transfer_fee;
        });
        let #Ok tx2 = res2 else {
            Debug.trap("transfer failed: " # debug_show(res2));
        };

        let res = await ICPLedger.icrc1_transfer({
            to = {
                owner = Principal.fromActor(CMC);
                subaccount = ?(Common.principalToSubaccount(Principal.fromActor(this)));
            };
            fee = null;
            memo = ?"TPUP\00\00\00\00";
            from_subaccount = null;
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = icpBalance - revenue - Common.icp_transfer_fee;
        });
        let #Ok tx = res else {
            Debug.trap("transfer failed: " # debug_show(res));
        };
        let res3 = await CMC.notify_top_up({
            block_index = Nat64.fromNat(tx);
            canister_id = Principal.fromActor(this);
        });
        let #Ok cyclesAmount = res3 else {
            Debug.trap("notify_top_up failed: " # debug_show(res2));
        };

        {balance = cyclesAmount};
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

    public query func balance(): async Nat {
        // TODO@P3: Allow only to the owner?
        Cycles.balance();
    };
}