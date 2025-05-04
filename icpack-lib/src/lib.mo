import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import ICRC1 "mo:icrc1-types";

module {
    public func withdrawCycles(ledger: ICRC1.Service, amount: Nat, payee: Principal, caller: Principal) : async* () {
        if (not Principal.isController(caller)) {
            Debug.trap("withdrawCycles: payee is not a controller");
        };
        switch (await ledger.icrc1_transfer({
            to = {owner = payee; subaccount = null};
            amount;
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
        })) {
            case (#Err e) {
                Debug.trap("withdrawCycles: " # debug_show(e));
            };
            case (#Ok _) {};
        };
    };
};