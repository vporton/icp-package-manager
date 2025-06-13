import Map "mo:base/OrderedMap";
import Principal "mo:base/Principal";

module {
  public func map(): Map.Operations<Principal> = Map.Make<Principal>(Principal.compare);

  public type Debts = Map.Map<Principal, Nat>;

  // FIXME@P1: What is `p`?
  public func indebt(args: {var debts: Debts; p : Principal; amount : Nat}) {
    let prev = switch (map().get(args.debts, args.p)) {
      case (?v) v;
      case null 0;
    };
    args.debts := map().put(args.debts, args.p, prev + args.amount);
  };

  public func debtOf(args: {var debts: Debts; p : Principal}) : Nat {
    switch (map().get(args.debts, args.p)) {
      case (?v) v;
      case null 0;
    }
  };
}
