/// Canister that takes on itself potentially non-returning calls.
import IC "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";

shared({caller = initialOwner}) actor class IndirectCaller() {
    var owner = initialOwner;

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("only owner");
        };
    };

    public shared({caller}) func changeOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    private func callAllOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
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
    private func callIgnoringMissingOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
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

    public shared({caller}) func callIgnoringMissingOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        await* callIgnoringMissingOneWayImpl(caller, methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        await* callAllOneWayImpl(caller, methods);
    };

    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        try {
            return await IC.call(method.canister, method.name, method.data); 
        }
        catch (e) {
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    public shared({caller}) func call(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        await IC.call(method.canister, method.name, method.data);
    };
}