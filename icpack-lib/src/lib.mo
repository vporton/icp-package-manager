import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Nat64 "mo:core/Nat64";

module {
    type BlockIndex = Nat;

    type Account = { owner : Principal; subaccount : ?[Nat8] };

    type WithdrawArgs = {
        amount : Nat;
        created_at_time : ?Nat64;
        from_subaccount : ?[Nat8];
        to : Principal
    };

    type RejectionCode =
      {
        #CanisterError;
        #CanisterReject;
        #DestinationInvalid;
        #NoError;
        #SysFatal;
        #SysTransient;
        #Unknown
      };

    type WithdrawError =
      {
        #BadFee : {expected_fee : Nat};
        #CreatedInFuture : {ledger_time : Nat64};
        #Duplicate : {duplicate_of : Nat};
        #FailedToWithdraw :
          {
            fee_block : ?Nat;
            rejection_code : RejectionCode;
            rejection_reason : Text
          };
        #GenericError : {error_code : Nat; message : Text};
        #InsufficientFunds : {balance : Nat};
        #InvalidReceiver : {receiver : Principal};
        #TemporarilyUnavailable;
        #TooOld
      };

    /// Interface for the cycles ledger actor used to perform withdrawals.
    public type CyclesLedger = actor {
        withdraw : shared WithdrawArgs -> async { #Err : WithdrawError; #Ok : BlockIndex };
    };

    public func withdrawCycles(ledger: CyclesLedger, amount: Nat, payee: Principal, caller: Principal) : async* () {
        if (not Principal.isController(caller)) {
            Debug.trap("withdrawCycles: payee is not a controller");
        };
        let res = await ledger.withdraw({
            amount;
            from_subaccount = null;
            to = payee;
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            fee = null;
            memo = null;
        });
        let #Ok _ = res else {
            Debug.trap("transfer failed: " # debug_show(res));
        };
    };
};