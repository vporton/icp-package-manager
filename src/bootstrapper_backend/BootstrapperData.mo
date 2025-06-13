import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import RBTree "mo:base/RBTree";
import Map "mo:base/OrderedMap";
import ICRC1Types "mo:icrc1-types";
import PST "canister:pst";
import ledger "canister:nns-ledger";
import Debt "../lib/Debt";

persistent actor class BootstrapperData(initialOwner: Principal) {
    public type PubKey = Blob;

    stable var owner = initialOwner;

    public shared({caller}) func changeOwner(newOwner: Principal) {
        if (not Principal.isController(caller)) {
            Debug.trap("bootstrapper_data: not a controller");
        };
        owner := newOwner;
    };

    public type FrontendTweaker = {
        // controllers: [Principal]; // pass them from UI, it's safe.
        frontend: Principal;
        user: Principal; // bootstrap frontend user
    };

    /// Frontend canisters belong to bootstrapper canister. We move them to new owners.
    transient var frontendTweakers = RBTree.RBTree<PubKey, FrontendTweaker>(Blob.compare);
    stable var _frontendTweakersSave = frontendTweakers.share();
    transient var frontendTweakerTimes = RBTree.RBTree<Time.Time, PubKey>(Int.compare);
    stable var _frontendTweakerTimesSave = frontendTweakerTimes.share();
    transient let principalMap = Map.Make<Principal>(Principal.compare);

    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("bootstrapper_data: not the owner");
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public shared({caller}) func putFrontendTweaker(pubKey: Blob, tweaker: FrontendTweaker): async () {
        onlyOwner(caller);

        frontendTweakers.put(pubKey, tweaker);
        frontendTweakerTimes.put(Time.now(), pubKey);
    };

    public shared({caller}) func getFrontendTweaker(pubKey: PubKey): async FrontendTweaker {
        onlyOwner(caller);

        do { // clean memory by removing old entries
            let threshold = Time.now() - 2700 * 1_000_000_000; // 45 min
            var i = frontendTweakerTimes.entries();
            label x loop {
                let ?(time, pubKey) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    frontendTweakerTimes.delete(time);
                    frontendTweakers.delete(pubKey);
                } else {
                    break x;
                };
            };
        };
        let ?res = frontendTweakers.get(pubKey) else {
            Debug.trap("no such frontend or key expired");
        };
        res;
    };

    public shared({caller}) func deleteFrontendTweaker(pubKey: PubKey): async () {
        onlyOwner(caller);

        frontendTweakers.delete(pubKey);
        // TODO@P3: Remove also from `frontendTweakerTimes`.
    };

    system func preupgrade() {
        _frontendTweakersSave := frontendTweakers.share();
        _frontendTweakerTimesSave := frontendTweakerTimes.share();
    };

    system func postupgrade() {
        frontendTweakers.unshare(_frontendTweakersSave);
        frontendTweakerTimes.unshare(_frontendTweakerTimesSave);
        
        // Free memory:
        frontendTweakers := RBTree.RBTree<PubKey, FrontendTweaker>(Blob.compare);
        frontendTweakerTimes := RBTree.RBTree<Time.Time, PubKey>(Int.compare);
    };

    public type Token = { #icp; #cycles };

    stable var debtsICP: Debt.Debts = 0;
    stable var debtsCycles: Debt.Debts = 0;

    public shared func indebt({caller: Principal; amount: Nat; token: Token}): () {
        switch token {
            // FIXME@P1: The variables `debtsICP` and `debtsCycles` are not changed!
            case (#icp) { Debt.indebt({var debts = debtsICP; amount}); };
            case (#cycles) { Debt.indebt({var debts = debtsCycles; amount}); };
        };
    };

    /// Dividends and Withdrawals ///

    /// Dividends are accounted per token to avoid newly minted PST receiving
    /// a share of previously declared dividends.  `dividendPerToken*` store the
    /// cumulative dividend amount scaled by `DIVIDEND_SCALE`.
    let DIVIDEND_SCALE : Nat = 1_000_000_000;
    stable var dividendPerTokenICP = 0;
    stable var dividendPerTokenCycles = 0;
    // TODO: Set a heavy transfer fee of the PST to ensure that `lastDividendsPerToken*` doesn't take much memory.
    stable var lastDividendsPerTokenICP = principalMap.empty<Nat>();
    stable var lastDividendsPerTokenCycles = principalMap.empty<Nat>();

    private func _dividendsOwing(_account: Principal, balance: Nat, token: Token): Nat {
        let last = switch token {
            case (#icp) { switch (principalMap.get(lastDividendsPerTokenICP, _account)) {
                    case (?value) { value };
                    case (null) { 0 };
                }
            };
            case (#cycles) { switch (principalMap.get(lastDividendsPerTokenCycles, _account)) {
                    case (?value) { value };
                    case (null) { 0 };
                }
            };
        };
        let perTokenDelta = switch token {
            case (#icp) { Int.abs((dividendPerTokenICP: Int) - last) };
            case (#cycles) { Int.abs((dividendPerTokenCycles: Int) - last) };
        };
        balance * perTokenDelta / DIVIDEND_SCALE;
    };

    // TODO@P3: Two duplicate functions.
    public composite query({caller}) func dividendsOwing() : async Nat {
        _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #icp);
    };

    public composite query({caller}) func dividendsOwingCycles() : async Nat {
        _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #cycles);
    };

    func recalculateShareholdersDebt(_amount: Nat, _buyerAffiliate: ?Principal, _sellerAffiliate: ?Principal, token: Token) : async () {
        // Affiliates are delivered by frontend.
        // address payable _buyerAffiliate = affiliates[msg.sender];
        // address payable _sellerAffiliate = affiliates[_author];
        var _shareHoldersAmount = _amount;
        let totalSupply = await PST.icrc1_total_supply();
        switch token {
            case (#icp) { dividendPerTokenICP += _shareHoldersAmount * DIVIDEND_SCALE / totalSupply };
            case (#cycles) { dividendPerTokenCycles += _shareHoldersAmount * DIVIDEND_SCALE / totalSupply };
        };
    };

    /// Withdraw owed dividends and record the snapshot of `dividendPerToken*`
    /// for the caller so that newly minted tokens do not get past dividends.
    public shared({caller}) func withdrawDividends() : async Nat {
        let amount = _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #icp);
        if (amount == 0) {
            return 0;
        };
        lastDividendsPerTokenICP := principalMap.put(lastDividendsPerTokenICP, caller, dividendPerTokenICP);
        ignore indebt({caller; amount; token = #icp});
        amount;
    };

    public shared({caller}) func withdrawCyclesDividends() : async Nat {
        let amount = _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #cycles);
        if (amount == 0) {
            return 0;
        };
        lastDividendsPerTokenCycles := principalMap.put(lastDividendsPerTokenCycles, caller, dividendPerTokenCycles);
        ignore indebt({caller; amount; token = #cycles});
        amount;
    };

    /// Outgoing Payments ///

    type OutgoingPayment = {
        amount: Nat;
        var time: ?Time.Time;
    };

    stable var ourDebts = principalMap.empty<OutgoingPayment>();

    public shared({caller}) func payout(subaccount: ?ICRC1Types.Subaccount) {
        switch (principalMap.get(ourDebts, caller)) {
            case (?payment) {
                let time = switch (payment.time) {
                    case (?time) { time };
                    case (null) {
                        let time = Time.now();
                        payment.time := ?time;
                        time;
                    }
                };
                let fee = await ledger.icrc1_fee();
                let result = await ledger.icrc1_transfer({
                    from_subaccount = null;
                    to = {owner = caller; subaccount = subaccount};
                    amount = payment.amount - fee;
                    fee = null;
                    memo = null;
                    created_at_time = ?Nat64.fromNat(Int.abs(time)); // idempotent
                });
                ignore principalMap.delete(ourDebts, caller);
            };
            case (null) {};
        };
    };
}