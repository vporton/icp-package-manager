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
        initial_balances = [({owner = initialOwner; subaccount = null}, 33334 * 4 * 10**8)]; // 80% of the supply
        max_supply = 33334 * 5 * 10**8; // Buying all tokens would mean 20% of the equity.
        min_burn_amount = 100_000;
        minting_account = { owner = Principal.fromActor(this); subaccount = null; }; // wallet can mint
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
<<<<<<< HEAD
=======
    ///
    /// The amount of tokens minted is determined by integrating a price curve
    /// over the caller's investment.  Initially, each ICP buys 4/3 ICPACK.  At
    /// 16,666.66 ICP invested in total the rate drops to half that, and after
    /// twice that amount of ICP is invested the cost grows without bound.  The
    /// integral ensures that investing 16,666.66 ICP mints exactly the same
    /// amount of ICPACK while early investors receive proportionally more.
>>>>>>> 163c221a607bfda9a89c993db575808c835c5191
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

        //
        // The number of PST tokens minted for an ICP investment is given by
        // integrating a price curve which gradually increases the cost of a token
        // as more ICP is invested.  The shape of the curve is chosen so that:
        //   * investing 16,666.66 ICP in total results in 16,666.66 newly minted
        //     ICPACK tokens (one token per ICP on average);
        //   * at the very beginning the buyer receives twice as many ICPACK per
        //     ICP as at the 16,666.66 ICP mark; and
        //   * once twice that amount of ICP (33,333.32 ICP) has been invested,
        //     the price tends to infinity and no new ICPACK can be purchased.
        //
        // These conditions are satisfied when the instantaneous number of
        // ICPACK tokens obtainable for one ICP is a linear function of the total
        // amount of ICP already invested, `f(x) = 4/3 * (1 - x/b)` where `b` is
        // twice 16,666.66 ICP expressed in e8s.  Integrating `f(x)` from the
        // previous total investment (`prevTotal`) to the new total investment
        // (`newTotal`) yields the number of ICPACK tokens to mint.  The result is the
        // expression below.

        let limit = 3_333_332_000_000; // investment cap (2 * 16_666.66 ICP) in e8s
        if (totalInvested + invest > limit) {
            // Once the limit is reached the cost of ICPACK grows without bound
            // because the `f(x)` factor in the integral approaches zero, so the
            // token price 1/f(x) tends to infinity and no further tokens can be purchased.
            return #Err(#GenericError{ error_code = 1; message = "investment overflow" });
        };

        let prevTotal = Int.fromNat(totalInvested);
        let newTotal = Int.fromNat(totalInvested + invest);
        let b = Int.fromNat(limit);
        // Integral of f(x) = 4/3 * (1 - x/b) from `prevTotal` to `newTotal` equals
        //  [4 * ((2*b*(newTotal-prevTotal)) - (newTotal^2 - prevTotal^2))] / (6*b).
        let numerator = 4 * ((2 * b * (newTotal - prevTotal)) - ((newTotal * newTotal) - (prevTotal * prevTotal)));
        let denominator = 6 * b;
        // This evaluates \int_{prevTotal}^{newTotal} f(x) dx where f(x) is the
        // instantaneous ICPACK per ICP rate.  The integer division is intentional
        // as ICP and ICPACK are denominated in e8s.

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
