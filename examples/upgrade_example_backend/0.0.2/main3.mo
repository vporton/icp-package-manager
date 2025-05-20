import LIB "mo:icpack-lib";
import CyclesLedger "canister:cycles_ledger";

actor {
  public shared func f() {};

  public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
    await* LIB.withdrawCycles(amount, payee, caller);
  };
}
