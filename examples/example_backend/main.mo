import LIB "mo:icpack-lib";
import CyclesLedger "canister:nns-ledger";

actor {
  public query func greet(name : Text) : async Text {
    return "Hello, " # name # "!";
  };

  public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
    await* LIB.withdrawCycles(amount, payee, caller);
  };
};
