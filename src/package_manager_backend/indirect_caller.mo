import IC "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";

actor {
    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    public shared func callAll(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        for (method in methods.vals()) {
            ignore await IC.call(method.canister, method.name, method.data); 
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, keep calling other methods.
    public shared func callIgnoringMissing(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                    throw e; // Other error cause interruption.
                }
            }
        };
    };
}