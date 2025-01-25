import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import RBTree "mo:base/RBTree";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Debug "mo:base/Debug";

actor class BootstrapperData(initialOwner: Principal) {
    public type PubKey = Blob;

    stable var owner = initialOwner;

    /// TODO: Save/load on cansiter upgrade.
    /// Frontend canisters belong to bootstrapper canister. We move them to new owners.
    let frontendTweakers = HashMap.HashMap<Principal, PubKey>(1, Principal.equal, Principal.hash); // TODO: Make it stable?
    /// TODO: Save/load on cansiter upgrade.
    let frontendTweakerTimes = RBTree.RBTree<Time.Time, Principal>(Int.compare); // TODO: Make it stable?

    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("BootstrapperData: not the owner");
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public shared({caller}) func putFrontendTweaker(frontendCanister: Principal, pubKey: Blob): async () {
        onlyOwner(caller);

        frontendTweakers.put(frontendCanister, pubKey);
        frontendTweakerTimes.put(Time.now(), frontendCanister);
    };

    public shared({caller}) func getFrontendTweaker(frontendCanister: Principal): async PubKey {
        onlyOwner(caller);

        do { // clean memory by removing old entries
            let threshold = Time.now() - 2700 * 1_000_000_000; // 45 min // TODO: make configurable?
            var i = RBTree.iter(frontendTweakerTimes.share(), #fwd);
            label x loop {
                let ?(time, principal) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    frontendTweakerTimes.delete(time);
                    frontendTweakers.delete(principal);
                } else {
                    break x;
                };
            };
        };
        let ?pubKey = frontendTweakers.get(frontendCanister) else {
            Debug.trap("no such frontend or key expired");
        };
        pubKey;
    };

    public shared({caller}) func deleteFrontendTweaker(frontendCanister: Principal): async () {
        onlyOwner(caller);

        frontendTweakers.delete(frontendCanister);
    };
}