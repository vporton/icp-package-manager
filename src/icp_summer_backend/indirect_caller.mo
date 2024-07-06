import IC "mo:base/ExperimentalInternetComputer";

actor {
    /// Call methods in the given order and don't return.
    public shared func callCanisters(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        for (method in methods.vals()) {
            ignore await IC.call(method.canister, method.name, method.data); 
        };
    }
}