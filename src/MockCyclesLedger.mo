/// Mock `CyclesLedger.create_canister` implementation using `IC.create_canister` (for testing).
/// IT DOES NOT CONFORM TO THE SPECS!
/// It's useful for testing code using `CyclesLedger.create_canister` on local net.
import Principal "mo:base/Principal";
// import IC "mo:ic";

actor MockCyclesLedger {
    // Cycles Ledger API

    type BlockIndex = Nat;

    type CreateCanisterArgs = {
        from_subaccount : ?[Nat8];
        created_at_time : ?Nat64;
        amount : Nat;
        creation_args : ?CmcCreateCanisterArgs;
    };

    type CmcCreateCanisterArgs = {
        settings : ?CanisterSettings;
        subnet_selection : ?SubnetSelection;
    };

    type CanisterSettings = {
        controllers : ?[Principal];
        compute_allocation : ?Nat;
        memory_allocation : ?Nat;
        freezing_threshold : ?Nat;
    };

    type SubnetFilter = {
        subnet_type : ?Text;
    };

    type SubnetSelection = {
        /// Choose a specific subnet
        #Subnet : {
            subnet : Principal;
        };
        #Filter : SubnetFilter;
    };

    type CreateCanisterSuccess = {
        block_id : BlockIndex;
        canister_id : Principal;
    };

    type CreateCanisterError = {
        #InsufficientFunds : { balance : Nat };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #TemporarilyUnavailable;
        #Duplicate : { duplicate_of : Nat };
        #FailedToCreate : {
            fee_block : ?BlockIndex;
            refund_block : ?BlockIndex;
            error : Text;
        };
        #GenericError : { message : Text; error_code : Nat };
    };

    // Mock implementation follows

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

    type AllowanceArgs = {
        account : Account;
        spender : Account;
    };

    type Allowance = {
        allowance : Nat;
        expires_at : ?Nat64;
    };

	public query func icrc2_allowance(_args: AllowanceArgs): async Allowance {
        { allowance = 10_000_000_000_000; expires_at = null };
    };

    type ApproveArgs = {
        fee : ?Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        expected_allowance : ?Nat;
        expires_at : ?Nat64;
        spender : Account;
    };

    type ApproveResult = {
        #Ok : Nat;
        #Err : ApproveError;
    };

    type ApproveError = {
        #GenericError : {
            message : Text;
            error_code : Nat;
        };
        #TemporarilyUnavailable;
        #Duplicate : {
            duplicate_of : Nat;
        };
        #BadFee : {
            expected_fee : Nat;
        };
        #AllowanceChanged : {
            current_allowance : Nat;
        };
        #CreatedInFuture : {
            ledger_time : Nat64;
        };
        #TooOld;
        #Expired : {
            ledger_time : Nat64;
        };
        #InsufficientFunds : {
            balance : Nat;
        }
    };

	public shared func icrc2_approve(args: ApproveArgs): async ApproveResult {
        #Ok(args.amount);
    };

    type TransferFromArgs = {
        to : Account;
        fee : ?Nat;
        spender_subaccount : ?Blob;
        from : Account;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
    };

    type TransferFromResult = {
        #Ok : Nat;
        #Err : TransferFromError;
    };

    type TransferFromError = {
        #GenericError : {
            message : Text;
            error_code : Nat;
        };
        #TemporarilyUnavailable;
        #InsufficientAllowance : {
            allowance : Nat;
        };
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
            ledger_time : Nat64;
        };
        #TooOld;
        #InsufficientFunds : {
            balance : Nat;
        }
    };

    public shared func icrc2_transfer_from(args: TransferFromArgs): async TransferFromResult {
        #Ok(args.amount);
    };
}