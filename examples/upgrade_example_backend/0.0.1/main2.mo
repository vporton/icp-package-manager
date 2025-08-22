import LIB "mo:icpack-lib";
import CyclesLedger "canister:cycles_ledger";
import Principal "mo:core/Principal";

persistent actor {
  public shared func f() {};

  // TODO@P3: use other withdraw function.
  public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
    await* LIB.withdrawCycles(CyclesLedger, amount, payee, caller);
  };
}
