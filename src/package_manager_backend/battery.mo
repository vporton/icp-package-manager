/// Battery canister or battery module is a canister that holds cycles and delivers them to other canisters.
import Timer "mo:core/Timer";
import Runtime "mo:core/Runtime";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Int "mo:core/Int";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Map "mo:core/Map";
import Set "mo:core/Set";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Cycles "mo:core/Cycles";
import Float "mo:core/Float";
import Common "../common";
import IC "mo:ic";
import LIB "mo:icpack-lib";
import Nat64 "mo:core/Nat64";
import ICPLedger "canister:nns-ledger";
import CyclesLedger "canister:cycles_ledger";
import CMC "canister:nns-cycles-minting";
import BootstrapperData "canister:bootstrapper_data";
import env "mo:env";

shared({caller = initialOwner}) persistent actor class Battery({
    packageManager: Principal; // may be the bootstrapper instead.
    mainIndirect: Principal;
    simpleIndirect: Principal;
    user: Principal;
    installationId = _: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // TODO@P3: Use `Set` instead of `Map`.
    stable var owners: Map.Map<Principal, ()> =
        Map.fromIter(
            [
                (packageManager, ()),
                (mainIndirect, ()), // temporary
                (simpleIndirect, ()),
                (Principal.fromActor(this), ()), // to execute the timer
                (user, ()),
            ].vals(),
            Principal.compare);

    func onlyOwner(caller: Principal, msg: Text): async* () {
        if (Map.get(owners, Principal.compare, caller) == null) {
            Runtime.trap("not the owner: " # msg);
        };
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

        ignore Map.delete<Principal, ()>(owners, Principal.compare, oldOwner);
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(Map.keys(owners));
    };

    stable var initialized = false;

    public shared({caller}) func init() : async () {
        await* onlyOwner(caller, "init");
        if (initialized) {
            Runtime.trap("already initialized");
        };

        initTimer<system>();

        initialized := true;
    };

    public query func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async () {
        if (not initialized) {
            Runtime.trap("battery: not initialized");
        };
    };

    stable let revenueRecipient = Principal.fromText(env.revenueRecipient);

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

    public type CanisterMap = Map.Map<ModuleLocation, CanisterKind>;

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
            canisterMap = Map.empty<ModuleLocation, CanisterKind>();
            canisterKindsMap = Map.empty<Text, Common.CanisterFulfillment>();
            var activatedCycles = 0;
        };

    public query func getCanisterInitialCycles(): async Nat {
        // await* onlyOwner(caller, "setDefaultFulfillment");

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
            let kind = Map.get(battery.canisterMap, compareModuleLocation, canister)!;
            Map.get(battery.canisterKindsMap, Text.compare, kind)!;
        };
        let fulfillment = switch (info0) {
            case (?x) x;
            case null battery.defaultFulfillment;
        };
        let mainIndirectActor = actor(Principal.toText(mainIndirect)) : actor {
            topUpOneCanisterFinish: shared (canister_id: Principal, fulfillment: Common.CanisterFulfillment) -> async ();
        };
        ignore(with cycles = fulfillment.topupAmount) mainIndirectActor.topUpOneCanisterFinish(canister_id, fulfillment);
    };

    private func topUpAllCanisters(): async () {
        let newCycles = Int.abs(+Cycles.balance() - battery.activatedCycles);
        if (newCycles != 0) {
            let fee = Int.abs(Float.toInt(Float.fromInt(newCycles) * env.revenueShare));
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

    stable var withdrawers = Set.empty<Principal>();

    /// TODO@P3: Make it editable using user confirmation.
    private func addWithdrawer(withdrawer: Principal) {
        ignore Set.insert<Principal>(withdrawers, Principal.compare, withdrawer);
    };

    addWithdrawer(mainIndirect);
    addWithdrawer(packageManager);

    public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
        await* LIB.withdrawCycles(CyclesLedger, amount, payee, caller);
    };

    public shared({caller}) func depositCycles(amount: Nat, payee: CyclesLedger.Account) : async () {
        ignore await (with cycles = amount) CyclesLedger.deposit({
            to = payee;
            memo = null;
        });
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
            Runtime.trap("withdrawCycles3: caller is not allowed");
        };
        if (Cycles.balance() < amount) {
            Runtime.trap("not enough cycles");
        };
        await (with cycles = amount) IC.ic.deposit_cycles({canister_id = payee});
    };

    public shared({caller}) func withdrawAllCycles() {
        await* onlyOwner(caller, "withdrawCycles");

        let balance = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = null;
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(balance) * env.revenueShare));
        let res2 = await CyclesLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.cycles_transfer_fee;
        });
        let #Ok tx = res2 else {
            Runtime.trap("revenue transfer failed: " # debug_show(res2));
        };

        let res = await CyclesLedger.withdraw({
            amount = balance - revenue - Common.cycles_transfer_fee;
            from_subaccount = null;
            to = Principal.fromActor(this);
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
        });
        let #Ok _ = res else {
            Runtime.trap("transfer failed: " # debug_show(res));
        };
    };

    public shared({caller = user}) func convertICPToCycles(): async {balance: Nat} {
        let icpBalance = await ICPLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = null;
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(icpBalance) * env.revenueShare));
        let res2 = await ICPLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.icp_transfer_fee;
        });
        let #Ok tx2 = res2 else {
            Runtime.trap("revenue transfer failed: " # debug_show(res2));
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
            Runtime.trap("transfer failed: " # debug_show(res));
        };
        let res3 = await CMC.notify_top_up({
            block_index = Nat64.fromNat(tx);
            canister_id = Principal.fromActor(this);
        });
        let #Ok cyclesAmount = res3 else {
            Runtime.trap("notify_top_up failed: " # debug_show(res3));
        };

        {balance = cyclesAmount};
    };

    system func inspect({
        caller : Principal;
    }): Bool {
        // await* onlyOwner(caller, "inspect"/*TODO@P3*/);
        true;
    };

    system func postupgrade() {
        initTimer<system>();
    };

    public query func balance(): async Nat {
        // TODO@P3: Allow only to the owner?
        Cycles.balance();
    };
}