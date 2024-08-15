/// Mock `CyclesLedger.create_canister` implementation using `IC.create_canister` (for testing).
/// IT DOES NOT CONFORM TO THE SPECS!
/// It's useful for testing code using `CyclesLedger.create_canister` on local net.
///
/// TODO: Extract this to a separate MOPS package
import Cycles "mo:base/ExperimentalCycles";

actor {
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

    type CanisterCreator = actor {
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

    public shared func create_canister(args: CreateCanisterArgs): async ({ #Ok : CreateCanisterSuccess; #Err : CreateCanisterError }) {
        ignore Cycles.accept<system>(10_000_000_000_000); // FIXME
        let sub = do ? { args.creation_args!.settings! };
        Cycles.add<system>(10_000_000_000_000); // FIXME
        let { canister_id } = await IC.create_canister({
            settings = sub;
        });
        #Ok {
            block_id = 0;
            canister_id;
        };
    };
}