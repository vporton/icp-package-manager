import LIB "mo:icpack-lib";
import Principal "mo:base/Principal";

actor {
  public shared func f() {};

  // TODO@P3: use other withdraw function.
  public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
    await* LIB.withdrawCycles(amount, payee, caller);
  };
}
