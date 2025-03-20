/// Mock `CyclesLedger.create_canister` implementation using `IC.create_canister` (for testing).
/// IT DOES NOT CONFORM TO THE SPECS!
/// It's useful for testing code using `CyclesLedger.create_canister` on local net.
///
/// TODO: Extract this to a separate MOPS package
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import IC "mo:ic";

actor MockCyclesLedger {

    type CanisterId = Principal;

    type CreateCanisterResult = {
        canister_id : CanisterId;
    };

    type LogVisibility = {
        #controllers;
        #public_;
    };

    type CanisterSettings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        reserved_cycles_limit : ?Nat;
        log_visibility : ?LogVisibility;
        wasm_memory_limit : ?Nat;
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    type CreateCanisterArgs = {
        settings : ?CanisterSettings;
        sender_canister_version : ?Nat64;
    };

    // Mock implementation follows

    // TODO: `args.amount`
    public shared func create_canister(args: CreateCanisterArgs): async CreateCanisterResult {
        ignore Cycles.accept<system>(10_000_000_000_000);
        let sub = do ? { args.settings! };
        Cycles.add<system>(10_000_000_000_000);
        await IC.ic.create_canister({
            settings = sub;
            sender_canister_version = null; // TODO
        });
    };

    type Subaccount = Blob;

    type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

	public query func icrc1_balance_of(_account: Account): async Nat {
        10_000_000_000_000;
    };

    type Timestamp = Nat64;

    type TransferArgs = {
        to : Account;
        fee : ?Nat;
        memo : ?Blob;
        from_subaccount : ?Subaccount;
        created_at_time : ?Timestamp;
        amount : Nat;
    };

    type TransferError = {
        #GenericError : {
            message : Text;
            error_code : Nat;
        };
        #TemporarilyUnavailable;
        #BadBurn : {
            min_burn_amount : Nat;
        };
        #Duplicate : {
            duplicate_of : Nat;
        };
        #BadFee : {
            expected_fee : Nat;
        };
        #CreatedInFuture : {
            ledger_time : Timestamp;
        };
        #TooOld;
        #InsufficientFunds : {
            balance : Nat;
        }
    };

    type TransferResult = {
        #Ok : Nat;
        #Err : TransferError;
    };


    public shared func icrc1_transfer(_args: TransferArgs): async TransferResult {
        // Do nothing.
        #Ok 1;
    };
}