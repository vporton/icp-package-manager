actor class Counter() {
    var counter: Nat = 0;

    public shared func increase(): async ()  {
        counter += 1;
    };

    public query func get(): async Nat {
        counter;
    };
}