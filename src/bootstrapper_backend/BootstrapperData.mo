import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Trie "mo:base/Trie";
import Nat32 "mo:base/Nat32";

persistent actor class BootstrapperData(initialOwner: Principal) {
    public type PubKey = Blob;

    stable var owner = initialOwner;

    public type FrontendTweaker = {
        // controllers: [Principal]; // pass them from UI, it's safe.
        frontend: Principal;
        // user: Principal; // bootstrap frontend user
    };

    /// Frontend canisters belong to bootstrapper canister. We move them to new owners.
    stable var frontendTweakers = Trie.empty<PubKey, FrontendTweaker>(); // TODO: Can be unbalanced by a hacker.
    stable var frontendTweakerTimes = Trie.empty<Time.Time, PubKey>(); // TODO: inefficient

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

        frontendTweakers := Trie.put(
            frontendTweakers, {hash = Blob.hash(pubKey); key = pubKey}, Blob.equal, tweaker
        ).0;
        frontendTweakerTimes := Trie.put(
            // FIXME: hash should be a hash.
            frontendTweakerTimes, {hash = Nat32.fromNat(Int.abs(Time.now()) % (2**32)); key = Time.now()}, Int.equal, pubKey
        ).0;
    };

    public shared({caller}) func getFrontendTweaker(pubKey: PubKey): async FrontendTweaker {
        onlyOwner(caller);

        do { // clean memory by removing old entries
            let threshold = Time.now() - 2700 * 1_000_000_000; // 45 min
            var i = Trie.iter(frontendTweakerTimes);
            label x loop {
                let ?(time, pubKey) = i.next() else {
                    break x;
                };
                if (time < threshold) {
                    frontendTweakerTimes := Trie.remove(
                        // FIXME: hash should be a hash.
                        frontendTweakerTimes, {hash = Nat32.fromNat(Int.abs(time)); key = time}, Int.equal
                    ).0;
                    frontendTweakers := Trie.remove(frontendTweakers, {hash = Blob.hash(pubKey); key = pubKey}, Blob.equal).0;
                } else {
                    break x;
                };
            };
        };
        let ?res = Trie.get(frontendTweakers, {hash = Blob.hash(pubKey); key = pubKey}, Blob.equal) else {
            Debug.trap("no such frontend or key expired");
        };
        res;
    };

    // TODO: Also remove `frontendTweakerTimes` entry.
    public shared({caller}) func deleteFrontendTweaker(pubKey: PubKey): async () {
        onlyOwner(caller);

        frontendTweakers := Trie.remove(frontendTweakers, {hash = Blob.hash(pubKey); key = pubKey}, Blob.equal).0;
        // TODO: Remove also from `frontendTweakerTimes`.
    };
}