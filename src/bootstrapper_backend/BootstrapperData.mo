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

    public type FrontendTweaker = {
        // controllers: [Principal]; // pass them from UI, it's safe.
        frontend: Principal;
        // user: Principal; // bootstrap frontend user
    };

    /// TODO: Save/load on cansiter upgrade.
    /// Frontend canisters belong to bootstrapper canister. We move them to new owners.
    let frontendTweakers = HashMap.HashMap<PubKey, FrontendTweaker>(1, Blob.equal, Blob.hash); // TODO: Make it stable?
    /// TODO: Save/load on cansiter upgrade.
    let frontendTweakerTimes = RBTree.RBTree<Time.Time, PubKey>(Int.compare); // TODO: Make it stable?

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
            var i = RBTree.iter(frontendTweakerTimes.share(), #fwd);
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
    };
}