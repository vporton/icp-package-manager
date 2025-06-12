import BTree "mo:base/BTree";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import { test } "mo:test";

let DIVIDEND_SCALE : Nat = 1_000_000_000;
var dividendPerToken = 0;
var lastDividendsPerToken : BTree.BTree<Principal, Nat> = BTree.init<Principal, Nat>(null);
var balances : BTree.BTree<Principal, Nat> = BTree.init<Principal, Nat>(null);
var totalSupply : Nat = 0;
var debts : BTree.BTree<Principal, Nat> = BTree.init<Principal, Nat>(null);

func balanceOf(a : Principal) : Nat {
  switch (BTree.get(balances, Principal.compare, a)) {
    case (?b) b;
    case null 0;
  }
};

func mint(a : Principal, amount : Nat) {
  let current = balanceOf(a);
  balances := BTree.put(balances, Principal.compare, a, current + amount);
  totalSupply += amount;
};

func addDividends(amount : Nat) {
  if (totalSupply == 0) return;
  dividendPerToken += amount * DIVIDEND_SCALE / totalSupply;
};

func _dividendsOwing(a : Principal) : Nat {
  let last = switch (BTree.get(lastDividendsPerToken, Principal.compare, a)) {
    case (?v) v;
    case null 0;
  };
  let perTokenDelta = Int.abs((dividendPerToken : Int) - last);
  balanceOf(a) * perTokenDelta / DIVIDEND_SCALE;
};

func withdrawDividends(a : Principal) : Nat {
  let amount = _dividendsOwing(a);
  lastDividendsPerToken := BTree.put(lastDividendsPerToken, Principal.compare, a, dividendPerToken);
  amount;
};

func indebt(a : Principal, amount : Nat) {
  let prev = switch (BTree.get(debts, Principal.compare, a)) {
    case (?v) v;
    case null 0;
  };
  debts := BTree.put(debts, Principal.compare, a, prev + amount);
};

let alice = Principal.fromText("aaaaa-aa");
let bob = Principal.fromText("bbbbbb-bb");

// Test newly minted tokens don't receive past dividends
@test "no dividends for newly minted" {
  mint(alice, 100);
  addDividends(100); // one per token
  mint(bob, 100);    // minted after dividends
  assert withdrawDividends(bob) == 0;
};

@test "indebt before withdraw" {
  mint(alice, 100);
  addDividends(100); // one per token
  let amount = _dividendsOwing(alice);
  indebt(alice, amount);
  let withdrawn = withdrawDividends(alice);
  assert withdrawn == 100;
  assert (switch (BTree.get(debts, Principal.compare, alice)) { case (?v) v; case null 0 }) == 100;
};

@test "indebt after withdraw" {
  mint(bob, 100);
  addDividends(100); // one per token
  let withdrawn = withdrawDividends(bob);
  indebt(bob, withdrawn);
  assert withdrawn == 100;
  assert (switch (BTree.get(debts, Principal.compare, bob)) { case (?v) v; case null 0 }) == 100;
};
