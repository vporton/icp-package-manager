import Principal "mo:base/Principal";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import ICRC1 "mo:icrc1/ICRC1";
// import ICRC1Types "mo:icrc1/ICRC1/Types";
import ICPLedger "canister:nns-ledger";
import Common "../common";
import Int "mo:base/Int";

shared ({ caller = initialOwner }) actor class PST() : async ICRC1.FullInterface = this {
    stable let token = ICRC1.init({
        advanced_settings = null;
        decimals = 8;
        fee = 10_000; // same as ICP fee
        initial_balances = [];
        max_supply = 10_000_000_000;
        min_burn_amount = 100_000;
        minting_account = { owner = Principal.fromActor(this); subaccount = null; }; // wallet can mint // FIXME@P1: There are many wallet installations!
        name = "IC Pack PST token";
        symbol = "ICPACK";
    });

    /// Total invested ICP in e8s.
    stable var totalInvested : Nat = 0;

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

    public shared ({ caller }) func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
        await* ICRC1.mint(token, args, caller);
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

    /// Buy ICPACK with ICP transferred to the caller's subaccount.
    public shared({caller = user}) func buyWithICP() : async ICRC1.TransferResult {
        let subaccount = Common.principalToSubaccount(user);
        let icpBalance = await ICPLedger.icrc1_balance_of({
            owner = Principal.fromActor(this);
            subaccount = ?subaccount;
        });
        if (icpBalance <= Common.icp_transfer_fee) {
            return #Err(#GenericError{ error_code = 0; message = "no ICP" });
        };
        let invest = icpBalance - Common.icp_transfer_fee;
        switch(await ICPLedger.icrc1_transfer({
            to = { owner = Principal.fromActor(this); subaccount = null };
            fee = null;
            memo = null;
            from_subaccount = ?subaccount;
            created_at_time = null;
            amount = invest;
        })) {
            case (#Err e) { return #Err e };
            case (#Ok _) {};
        };

        let limit = 3_333_332_000_000; // 2 * 16_666.66 ICP in e8s
        if (totalInvested + invest > limit) {
            return #Err(#GenericError{ error_code = 1; message = "investment overflow" });
        };

        let prev = Int.fromNat(totalInvested);
        let new = Int.fromNat(totalInvested + invest);
        let b = Int.fromNat(limit);
        let numerator = 4 * ((2 * b * (new - prev)) - ((new * new) - (prev * prev)));
        let denominator = 6 * b;
        let minted = Nat.fromInt(numerator / denominator);
        totalInvested += invest;

        await this.mint({
            to = { owner = user; subaccount = null };
            amount = minted;
            memo = null;
        });
    };

    // Deposit cycles into this archive canister.
    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept<system>(amount);
        assert (accepted == amount);
    };
};
