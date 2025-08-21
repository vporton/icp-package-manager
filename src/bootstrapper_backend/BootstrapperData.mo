import Principal "mo:core/Principal";
import Blob "mo:core/Blob";
import Debug "mo:core/Debug";
import Time "mo:core/Time";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Map "mo:core/Map";
import UserAuth "mo:icpack-lib/UserAuth";
import Account "../lib/Account";

persistent actor class BootstrapperData(initialOwner: Principal) = this {
    public type PubKey = UserAuth.PubKey;
    public type FrontendTweaker = {
        frontend: Principal;
        user: Principal;
    };

    public type Token = { #icp; #cycles };

    stable var owner = initialOwner;

    transient var frontendTweakers = RBTree.RBTree<PubKey, FrontendTweaker>(Blob.compare);
    stable var _frontendTweakersSave = frontendTweakers.share();
    transient var frontendTweakerTimes = RBTree.RBTree<Time.Time, PubKey>(Int.compare);
    stable var _frontendTweakerTimesSave = frontendTweakerTimes.share();

    // User cycle balance management
    stable var userCycleBalanceMap = principalMap.empty<Principal, Nat>();

    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("bootstrapper_data: not the owner");
        };
    };

    public shared({caller}) func changeOwner(newOwner: Principal) {
        if (not Principal.isController(caller)) {
            Debug.trap("bootstrapper_data: not a controller");
        };
        owner := newOwner;
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public shared({caller}) func putFrontendTweaker(pubKey: PubKey, tweaker: FrontendTweaker): async () {
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
                let ?(time, pk) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    frontendTweakerTimes.delete(time);
                    frontendTweakers.delete(pk);
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

    // User cycle balance management functions
    public query({caller}) func getUserCycleBalance(user: Principal): async Nat {
        onlyOwner(caller);
        
        switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?amount) amount;
            case null 0;
        };
    };

    public shared({caller}) func updateUserCycleBalance(user: Principal, newBalance: Nat): async () {
        onlyOwner(caller);
        
        ignore Map.insert(userCycleBalanceMap, Principal.compare, user, newBalance);
    };

    public shared({caller}) func addToUserCycleBalance(user: Principal, amount: Nat): async () {
        onlyOwner(caller);
        
        let oldBalance = switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?oldBalance) oldBalance;
            case null 0;
        };
        ignore Map.insert(userCycleBalanceMap, Principal.compare, user, oldBalance + amount);
    };

    public shared({caller}) func removeUserCycleBalance(user: Principal): async Nat {
        onlyOwner(caller);
        
        let amountToMove = switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?amount) amount;
            case null 0;
        };
        ignore Map.delete(userCycleBalanceMap, Principal.compare, user);
        amountToMove;
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
}
