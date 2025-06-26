import Option "mo:base/Option";
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
import Error "mo:base/Error";
import ICRC1Types "mo:icrc1-types";
import Sha256 "mo:sha2/Sha256";
import Account "../lib/Account";
import Common "../common";
import PST "canister:pst";
import ledger "canister:nns-ledger";
import CyclesLedger "canister:cycles_ledger";

// TODO@P1: Add icrc3 and icrc4 code.
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

    private func tokenPrincipal(token: Token) : Principal {
        switch token {
            case (#icp) { Principal.fromActor(ledger) };
            case (#cycles) { Principal.fromActor(CyclesLedger) };
        };
    };

    /// Return the ICRC1 token canister for the provided token tag.
    private func icrc1Token(token: Token) : ICRC1Types.Service {
        actor(Principal.toText(tokenPrincipal(token)));
    };

    /// Helper to convert `Token` to an array index.
    private func tokenIndex(token: Token) : Nat {
        switch token {
            case (#icp) { 0 };
            case (#cycles) { 1 };
        };
    };

    // TODO@P1: Use a map from token principal, instead?
    // stable let debts = [var 0, 0];

    // FIXME@P1: This function does not decrease displayed amount of token, etc.
    /// I don't make this function reliable, because it is usually about small amounts of money.
    public shared func indebt({amount: Nat; token: Token}) {
        let i = tokenIndex(token);
        // debts[i] += amount;
        await* recalculateShareholdersDebt(amount, token);
    };

    /// Dividends and Withdrawals ///

    /// Dividends are accounted per token to avoid newly minted PST receiving
    /// a share of previously declared dividends.  `dividendPerToken*` store the
    /// cumulative dividend amount scaled by `DIVIDEND_SCALE`.
    let DIVIDEND_SCALE : Nat = 1_000_000_000;
    /// Accumulated dividend:
    stable let dividendPerToken = [var 0, 0];
    // TODO@P1: Set a heavy transfer fee of the PST to ensure that `dividendsCheckpointPerToken*` doesn't take much memory.
    /// Snapshot of (all, not per user) dividends at the last payment point for a particular user:
    stable var dividendsCheckpointPerToken = [var principalMap.empty<Nat>(), principalMap.empty<Nat>()];
    /// Indicates whether a withdrawal operation is in progress for a user.
    /// A lock entry for dividends withdrawal. `transferring` marks that a
    /// transfer to the temporary dividends account is in progress.
    /// A lock entry used to control concurrent dividends withdrawals.
    public type DividendsLock = {
        owedAmount: Nat;
        dividendsCheckpoint: Nat;
        transferring: Bool;
        createdAtTime: Nat64;
    };

    private let emptyDividendsLock : DividendsLock = {
        owedAmount = 0;
        dividendsCheckpoint = 0;
        transferring = false;
        createdAtTime = 0 : Nat64;
    };

    stable var lockDividendsAccount = [
        var principalMap.empty<DividendsLock>(),
        principalMap.empty<DividendsLock>()
    ];

    /// Return the lock entry for a user or trap if it doesn't exist.
    private func dividendsLock(i: Nat, user: Principal) : DividendsLock {
        switch (principalMap.get(lockDividendsAccount[i], user)) {
            case (?l) l;
            case null Debug.trap("dividends lock missing");
        }
    };

    /// Ensure that a lock entry exists and return it.
    private func ensureDividendsLock(i: Nat, user: Principal) : DividendsLock {
        switch (principalMap.get(lockDividendsAccount[i], user)) {
            case (?l) l;
            case null {
                lockDividendsAccount[i] := principalMap.put(lockDividendsAccount[i], user, emptyDividendsLock);
                emptyDividendsLock
            }
        }
    };

    private func _dividendsOwing(user: Principal, balance: Nat, token: Token): Nat {
        let i = tokenIndex(token);
        let lastMap = dividendsCheckpointPerToken[i];
        let last = switch (principalMap.get(lastMap, user)) {
            case (?value) { value };
            case (null) { 0 };
        };
        let perTokenDelta = Int.abs((dividendPerToken[i]: Int) - last);
        balance * perTokenDelta / DIVIDEND_SCALE;
    };

    // TODO@P3: Two duplicate functions.
    public composite query({caller}) func dividendsOwing(token: Token, user: Principal) : async Nat {
        _dividendsOwing(user, await PST.icrc1_balance_of({owner = user; subaccount = null}), token);
    };

    func recalculateShareholdersDebt(amount: Nat, token: Token) : async* () {
        let totalSupply = await PST.icrc1_total_supply();
        if (totalSupply == 0) { return; };
        let i = tokenIndex(token);
        dividendPerToken[i] += amount * DIVIDEND_SCALE / totalSupply;
        Debug.print("dividendPerToken: " # debug_show(dividendPerToken[i])); // FIXME: Remove.
    };

    private func accountHash(user: Principal): Blob {
      // TODO: duplicate code
      let random: Blob = "\c2\78\8d\f0\0e\52\bb\5b\0b\b8\e6\98\ae\b3\87\d2\aa\54\91\ee\61\36\c9\86\85\df\78\09\cd\98\90\50"; // unique 256 bit
      let joined = Array.append<Nat8>(Blob.toArray(random), Blob.toArray(Principal.toBlob(user)));
      Sha256.fromBlob(#sha256, Blob.fromArray(joined));
    };

    /// A temporary account for dividends before it is finally withdrawn.
    private func accountWithDividends(user: Principal): Account.Account {
      let subaccount = user;
      { owner = Principal.fromActor(this); subaccount = ?subaccount };
    };

    // TODO@P3: Can we simplify this function?
    public shared func getAccountWithDividends1(user: Principal): async Account.Account {
        accountWithDividends(user);
    };

    // TODO@P3: Can we simplify this function?
    public shared func getAccountWithDividends2(user: Principal): async {owner: Principal; subaccount: ?[Nat8]} {
        let account = accountWithDividends(user);
        let subaccount = switch (account.subaccount) {
            case (?subaccount) ?Blob.toArray(subaccount);
            case null null;
        };
        {owner = account.owner; subaccount};
    };

    /// Move owed dividends to a temporary account and mark the withdrawal as started.
    ///
    /// We may need to call this several times, because transfer may fail (e.g. due to network congestion).
    private func putDividendsOnTmpAccount(user: Principal, token: Token) : async Nat {
        let i = tokenIndex(token);
        let icrc1 = icrc1Token(token);
        try {
            // Create a lock entry if none exists so that concurrent calls don't compute the dividend twice.
            var lock = ensureDividendsLock(i, user);
            if (lock.owedAmount == 0) {
                let pstBalance = await PST.icrc1_balance_of({owner = user; subaccount = null});
                let amount = _dividendsOwing(user, pstBalance, token);
                let dividendsCheckpoint = dividendPerToken[i];
                lock := {owedAmount = amount; dividendsCheckpoint; transferring = false; createdAtTime = 0 : Nat64};
                lockDividendsAccount[i] := principalMap.put(lockDividendsAccount[i], user, lock);
            };
            var current = dividendsLock(i, user);
            let amount = current.owedAmount;

            if (amount <= Common.icp_transfer_fee) {
                lockDividendsAccount[i] := principalMap.delete(lockDividendsAccount[i], user);
                return 0;
            };
            if (not current.transferring) {
                let ts = if (current.createdAtTime == 0) { Nat64.fromNat(Int.abs(Time.now())) } else { current.createdAtTime };
                current := {current with transferring = true; createdAtTime = ts};
                lockDividendsAccount[i] := principalMap.put(lockDividendsAccount[i], user, current);
            };
            let res = await icrc1.icrc1_transfer({
                memo = null;
                amount = amount - Common.icp_transfer_fee;
                fee = null;
                from_subaccount = null;
                to = accountWithDividends(user);
                created_at_time = ?current.createdAtTime;
            });
            switch (res) {
                case (#Ok _) {};
                case (#Err(#Duplicate _)) {};
                case (#Err e) {
                    lockDividendsAccount[i] := principalMap.put(lockDividendsAccount[i], user, {current with transferring = false; createdAtTime = 0 : Nat64});
                    Debug.trap("transfer failed: " # debug_show(res));
                };
            };
            dividendsCheckpointPerToken[i] := principalMap.put(dividendsCheckpointPerToken[i], user, current.dividendsCheckpoint);
            lockDividendsAccount[i] := principalMap.delete(lockDividendsAccount[i], user);
            return amount;
        } catch (err) {
            let cur = dividendsLock(i, user);
            lockDividendsAccount[i] := principalMap.put(
                lockDividendsAccount[i],
                user,
                {cur with transferring = false; createdAtTime = 0 : Nat64},
            );
            Debug.trap("withdraw dividends failed: " # Error.message(err));
            0;
        };
    };

    /// Finish the withdrawal by sending dividends from the temporary account to the provided account.
    public shared({caller}) func finishWithdrawDividends(token: Token, to: Account.Account) : async Nat {
        // We don't need locking in this function, because we can't withdraw (from the tmp account) more than its balance.
        let i = tokenIndex(token);
        let acc = accountWithDividends(caller);
        let tokenSvc = icrc1Token(token);
        let amount = await tokenSvc.icrc1_balance_of(acc);
        if (amount <= Common.icp_transfer_fee) {
            // lockDividendsAccount[i] := principalMap.delete(lockDividendsAccount[i], accountHash(caller));
            return 0;
        };
        try {
            let res = await tokenSvc.icrc1_transfer({
                memo = null;
                amount = amount - Common.icp_transfer_fee;
                fee = null;
                from_subaccount = acc.subaccount;
                to;
                created_at_time = null;
            });
            let #Ok _ = res else {
                Debug.trap("transfer failed: " # debug_show(res));
            };
            amount;
        } catch (err) {
            Debug.trap("transfer failed: " # Error.message(err));
            0;
        };
    };

    /// Withdraw owed dividends and record the snapshot of `dividendPerToken*`
    /// for the caller so that newly minted tokens do not get past dividends.
    public shared({caller}) func withdrawDividends(token: Token, to: Account.Account) : async Nat {
        let moved = await putDividendsOnTmpAccount(caller, token);
        if (moved == 0) { return 0; };
        return await finishWithdrawDividends(token, to); // TODO: Use `await*`.
    };
}
