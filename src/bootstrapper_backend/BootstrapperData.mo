import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import RBTree "mo:base/RBTree";
import Map "mo:base/OrderedMap";
import Nat8 "mo:base/Nat8";
import ICRC1Types "mo:icrc1-types";
import Sha256 "mo:sha2/Sha256";
import Account "../lib/Account";
import PST "canister:pst";
import ledger "canister:nns-ledger";

persistent actor class BootstrapperData(initialOwner: Principal) = this {
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

    // TODO@P1: Use a map from token principal, instead?
    stable var debtsICP: Nat = 0;
    stable var debtsCycles: Nat = 0;

    /// I don't make this function reliable, because it is usually about small amounts of money.
    public shared func indebt({amount: Nat; token: Token}): () {
        switch token {
            case (#icp) { debtsICP += amount; };
            case (#cycles) { debtsCycles += amount; };
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
    public composite query({caller}) func dividendsOwing(token: Token) : async Nat {
        _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), token);
    };

    func recalculateShareholdersDebt(amount: Nat, token: Token) : async () {
        let totalSupply = await PST.icrc1_total_supply();
        switch token {
            case (#icp) { dividendPerTokenICP += amount * DIVIDEND_SCALE / totalSupply };
            case (#cycles) { dividendPerTokenCycles += amount * DIVIDEND_SCALE / totalSupply };
        };
    };

    // TODO@P2: needed?
    /// A temporary account for divideds before it is finally withdrawn.
    private func accountWithInvestment(user: Principal): Account.Account {
      // TODO: duplicate code
      let random: Blob = "\c2\78\8d\f0\0e\52\bb\5b\0b\b8\e6\98\ae\b3\87\d2\aa\54\91\ee\61\36\c9\86\85\df\78\09\cd\98\90\50"; // unique 256 bit
      let principalArray = Blob.toArray(random);
      let randomArray = Blob.toArray(random);
    //   let principalArray = Blob.toArray(binPrincipal);
      let joined = Array.tabulate(
        32 + Array.size(principalArray),
        func (i: Nat): Nat8 = if (i < 32) { randomArray[i] } else { principalArray[i-32] }
      );
      let subaccount = Sha256.fromBlob(#sha256, Blob.fromArray(joined));
      { owner = Principal.fromActor(this); subaccount = ?subaccount };
    };

    /// Withdraw owed dividends and record the snapshot of `dividendPerToken*`
    /// for the caller so that newly minted tokens do not get past dividends.
    public shared({caller}) func withdrawICPDividends() : async Nat {
        let amount = _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #icp);
        if (amount == 0) {
            return 0;
        };
        lastDividendsPerTokenICP := principalMap.put(lastDividendsPerTokenICP, caller, dividendPerTokenICP);
        ignore indebt({amount; token = #icp}); // FIXME@P1: seems superfluous
        amount;
    };

    public shared({caller}) func withdrawCyclesDividends() : async Nat {
        let amount = _dividendsOwing(caller, await PST.icrc1_balance_of({owner = caller; subaccount = null}), #cycles);
        if (amount == 0) {
            return 0;
        };
        lastDividendsPerTokenCycles := principalMap.put(lastDividendsPerTokenCycles, caller, dividendPerTokenCycles);
        ignore indebt({amount; token = #cycles}); // FIXME@P1: seems superfluous
        amount;
    };
}