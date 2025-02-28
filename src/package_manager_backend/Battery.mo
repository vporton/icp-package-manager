import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import StableHashMap "mo:stablehashmap/FunctionalStableHashMap";
import CyclesSimple "../lib/battery";

shared({caller = initialOwner}) actor class Battery() = this {
    stable var owners = [initialOwner];

    func checkCaller(caller: Principal) {
        if (Array.find(owners, func(e: Principal): Bool { e == caller; }) == null) {
            Debug.trap("battery: not allowed");
        }
    };

    public shared({caller = caller}) func setOwners(_owners: [Principal]): async () {
        checkCaller(caller);

        owners := _owners;
    };

    public query func getOwners(): async [Principal] { owners };

    stable var initialized = false;

    public shared({caller}) func init(_owners: [Principal]) : async () {
        checkCaller(caller);
        if (initialized) {
            Debug.trap("already initialized");
        };

        owners := _owners;

        CyclesSimple.insertCanisterKind(battery, "default", {
            threshold = 3_000_000_000_000;
            installAmount = 2_000_000_000_000;
        });
        initTimer<system>();

        initialized := true;
    };

    system func postupgrade() {
        initTimer<system>();
    };

    func initTimer<system>() {
        timer := ?(Timer.recurringTimer<system>(#seconds 3600, topUpAllCanisters));
    };

    stable let battery = CyclesSimple.newBattery();

    stable var timer: ?Timer.TimerId = null;

    public shared({caller}) func addCanister(principal: Principal, kind: Text) {
        checkCaller(caller);
        CyclesSimple.addCanister(battery, principal, kind);
    };

    private func topUpAllCanisters(): async () {
        await* CyclesSimple.topUpAllCanisters(battery);
    };

    system func inspect({
        caller : Principal;
    }): Bool {
        checkCaller(caller);
        true;
    }
}