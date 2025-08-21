import Principal "mo:core/Principal";
import Blob "mo:core/Blob";
import Error "mo:core/Error";
import Time "mo:core/Time";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Map "mo:core/Map";
import Result "mo:core/Result";
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

    stable var frontendTweakers = Map.empty<PubKey, FrontendTweaker>();
    stable var frontendTweakerTimes = Map.empty<Time.Time, PubKey>();

    // User cycle balance management
    stable var userCycleBalanceMap = Map.empty<Principal, Nat>();

    private func onlyOwner(caller: Principal): Result.Result<(), Text> {
        if (caller != owner) {
            return #err("bootstrapper_data: not the owner");
        };
        #ok();
    };

    public shared({caller}) func changeOwner(newOwner: Principal) {
        if (not Principal.isController(caller)) {
            throw Error.reject("bootstrapper_data: not a controller");
        };
        owner := newOwner;
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };

        owner := newOwner;
    };

    public shared({caller}) func putFrontendTweaker(pubKey: PubKey, tweaker: FrontendTweaker): async () {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };

        ignore Map.insert(frontendTweakers, Blob.compare, pubKey, tweaker);
        ignore Map.insert(frontendTweakerTimes, Int.compare, Time.now(), pubKey);
    };

    public shared({caller}) func getFrontendTweaker(pubKey: PubKey): async FrontendTweaker {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };

        do { // clean memory by removing old entries
            let threshold = Time.now() - 2700 * 1_000_000_000; // 45 min
            var i = Map.entries(frontendTweakerTimes);
            label x loop {
                let ?(time, pk) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    ignore Map.delete(frontendTweakerTimes, Int.compare, time);
                    ignore Map.delete(frontendTweakers, Blob.compare, pk);
                } else {
                    break x;
                };
            };
        };
        let ?res = Map.get(frontendTweakers, Blob.compare, pubKey) else {
            throw Error.reject("no such frontend or key expired");
        };
        res;
    };

    public shared({caller}) func deleteFrontendTweaker(pubKey: PubKey): async () {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };

        ignore Map.delete(frontendTweakers, Blob.compare, pubKey);
        // TODO@P3: Remove also from `frontendTweakerTimes`.
    };

    // User cycle balance management functions
    public query({caller}) func getUserCycleBalance(user: Principal): async Nat {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };
        
        switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?amount) amount;
            case null 0;
        };
    };

    public shared({caller}) func updateUserCycleBalance(user: Principal, newBalance: Nat): async () {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };
        
        ignore Map.insert(userCycleBalanceMap, Principal.compare, user, newBalance);
    };

    public shared({caller}) func addToUserCycleBalance(user: Principal, amount: Nat): async () {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };
        
        let oldBalance = switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?oldBalance) oldBalance;
            case null 0;
        };
        ignore Map.insert(userCycleBalanceMap, Principal.compare, user, oldBalance + amount);
    };

    public shared({caller}) func removeUserCycleBalance(user: Principal): async Nat {
        switch (onlyOwner(caller)) {
            case (#err e) throw Error.reject(e);
            case (#ok) {};
        };
        
        let amountToMove = switch (Map.get(userCycleBalanceMap, Principal.compare, user)) {
            case (?amount) amount;
            case null 0;
        };
        ignore Map.delete(userCycleBalanceMap, Principal.compare, user);
        amountToMove;
    };
}
