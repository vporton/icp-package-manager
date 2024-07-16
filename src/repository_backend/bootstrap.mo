import Array "mo:base/Array";
import Debug "mo:base/Debug";

shared({caller = originalOwner}) actor class Bootstrap() {
    stable var owner = originalOwner;

    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("not an owner");
        }
    };

    public query func getOwner(): async Principal {
        owner;
    };

    public shared({caller}) func setOwner(): async () {
        onlyOwner(caller);
        owner := caller;
    };

    stable var wasms: [Blob] = [];

    public query func getWasmsCount(): async Nat {
        Array.size(wasms);
    };

    public query func getWasm(index: Nat): async Blob {
        wasms[index];
    };

    /// The last should be the frontend WASM.
    public shared({caller}) func setWasms(newWasms: [Blob]): async () {
        onlyOwner(caller);
        wasms := newWasms;
    };

    public shared({caller}) func bootstrap() {

    }
}