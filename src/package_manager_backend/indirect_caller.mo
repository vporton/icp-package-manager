import IC "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";

shared({caller = owner}) actor class IndirectCaller() {
    // ignore Cycles.accept<system>(5_000_000_000_000); // FIXME

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("only owner");
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    public shared({caller}) func callAll(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        try {
            for (method in methods.vals()) {
                ignore await IC.call(method.canister, method.name, method.data); 
            };
        }
        catch (e) {
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, keep calling other methods.
    public shared({caller}) func callIgnoringMissing(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                Debug.trap("Indirect caller: " # Error.message(e));
                if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                    throw e; // Other error cause interruption.
                }
            };
        };
    };
}