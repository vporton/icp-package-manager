/// Mock `CyclesLedger.create_canister` implementation using `IC.create_canister` (for testing).
/// IT DOES NOT CONFORM TO THE SPECS!
/// It's useful for testing code using `CyclesLedger.create_canister` on local net.
///
/// TODO: Extract this to a separate MOPS package
import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";

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

    type canister_id = Principal;

    type CanisterCreator = actor { // TODO: Use `IC` module.
        create_canister : shared { settings : ?canister_settings } -> async {
            canister_id : canister_id;
        };
    };

    let IC: CanisterCreator = actor("aaaaa-aa");

    type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    // TODO: `args.amount`
    public shared func create_canister(args: CreateCanisterArgs): async ({ #Ok : CreateCanisterSuccess; #Err : CreateCanisterError }) {
        ignore Cycles.accept<system>(10_000_000_000_000);
        let sub = do ? { args.creation_args!.settings! };
        Cycles.add<system>(10_000_000_000_000);
        let { canister_id } = await IC.create_canister({
            settings = sub;
            // sender_canister_version = null; // TODO
        });
        #Ok {
            block_id = 0;
            canister_id;
        };
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