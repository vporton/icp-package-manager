import BTree "mo:base/BTree";
import Principal "mo:base/Principal";

module {
  public type Debts = BTree.BTree<Principal, Nat>;
  stable var debts : Debts = BTree.init<Principal, Nat>(null);

  public func indebt(p : Principal, amount : Nat) {
    let prev = switch (BTree.get(debts, Principal.compare, p)) {
      case (?v) v;
      case null 0;
    };
    debts := BTree.put(debts, Principal.compare, p, prev + amount);
  };

  public func debtOf(p : Principal) : Nat {
    switch (BTree.get(debts, Principal.compare, p)) {
      case (?v) v;
      case null 0;
    }
  };
}
