// Debt tracking utilities. All debts belong to PST holders collectively.
/// TODO@P3: Delete this file.
module {
  /// Mutable debt value.
  public type Debts = Nat;

  /// Increase `debts` by `amount`.
  public func indebt(args : { var debts : Debts; amount : Nat }) {
    args.debts := args.debts + args.amount;
  };

  /// Return the current debt amount.
  public func debtOf(args : { var debts : Debts }) : Nat {
    args.debts
  };
}
