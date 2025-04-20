/// Mock `CyclesLedger.create_canister` implementation using `IC.create_canister` (for testing).
/// IT DOES NOT CONFORM TO THE SPECS!
/// It's useful for testing code using `CyclesLedger.create_canister` on local net.
import Principal "mo:base/Principal";
// import IC "mo:ic";
import ICRC1 "mo:icrc1/ICRC1";
import T "mo:icrc1/ICRC1/Types";
import Option "mo:base/Option";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";

shared({ caller = _owner }) actor class MockCyclesLedger(
    token_args : ICRC1.TokenInitArgs,
) : async ICRC1.FullInterface {
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

    stable let token = ICRC1.init({
        token_args with minting_account = Option.get(
            token_args.minting_account,
            {
                owner = _owner;
                subaccount = null;
            },
        );
    });

    /// Functions for the ICRC1 token standard
    public shared query func icrc1_name() : async Text {
        ICRC1.name(token);
    };

    public shared query func icrc1_symbol() : async Text {
        ICRC1.symbol(token);
    };

    public shared query func icrc1_decimals() : async Nat8 {
        ICRC1.decimals(token);
    };

    public shared query func icrc1_fee() : async ICRC1.Balance {
        ICRC1.fee(token);
    };

    public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
        ICRC1.metadata(token);
    };

    public shared query func icrc1_total_supply() : async ICRC1.Balance {
        ICRC1.total_supply(token);
    };

    public shared query func icrc1_minting_account() : async ?ICRC1.Account {
        ?ICRC1.minting_account(token);
    };

    public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
        ICRC1.balance_of(token, args);
    };

    public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
        ICRC1.supported_standards(token);
    };

    public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
        await* ICRC1.transfer(token, args, caller);
    };

    /// In our mock object, anyone can mint.
    public shared func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
        // await* ICRC1.mint(token, args, caller);
        let transfer_args : T.TransferArgs = {
            args with from_subaccount = token.minting_account.subaccount;
            fee = null;
        };

        await* ICRC1.transfer(token, transfer_args, token.minting_account.owner);
    };

    public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
        await* ICRC1.burn(token, args, caller);
    };

    // Functions from the rosetta icrc1 ledger
    public shared query func get_transactions(req : ICRC1.GetTransactionsRequest) : async ICRC1.GetTransactionsResponse {
        ICRC1.get_transactions(token, req);
    };

    // Additional functions not included in the ICRC1 standard
    public shared func get_transaction(i : ICRC1.TxIndex) : async ?ICRC1.Transaction {
        await* ICRC1.get_transaction(token, i);
    };

    // Deposit cycles into this archive canister.
    public shared func deposit_cycles() : async () { // TODO@P3: needed?
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept<system>(amount);
        assert (accepted == amount);
    };
}