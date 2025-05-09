import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";

module {
    type BlockIndex = Nat;

    type Account = { owner : Principal; subaccount : ?[Nat8] };

    type TransferArgs = {
        from_subaccount : ?[Nat8];
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?[Nat8];
        created_at_time : ?Nat64;
    };

    type TransferError = {
      #BadFee : { expected_fee : Nat };
        #BadBurn : { min_burn_amount : Nat };
        #InsufficientFunds : { balance : Nat };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError : { message : Text; error_code : Nat };
    };

    public type MyICRC1 = actor {
        icrc1_transfer : shared TransferArgs -> async {#Err : TransferError; #Ok : BlockIndex};
    };

    public func withdrawCycles(ledger: MyICRC1, amount: Nat, payee: Principal, caller: Principal) : async* () {
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