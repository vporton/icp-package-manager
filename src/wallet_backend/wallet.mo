import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import ICRC1 "mo:icrc1-types";
import ICPLedger "canister:nns-ledger";

persistent actor class Wallet({
    user: Principal; // Pass the anonymous principal `2vxsx-fae` to be controlled by nobody.
}) = this {
    let owner = user;

    private func onlyOwner(caller: Principal, msg: Text) {
        if (not Principal.isAnonymous(owner) and caller != owner) {
            Debug.trap(msg # ": no owner set");
        };
    };

    type Token = {
        symbol: Text;
        name: Text;
        canisterId: Principal;
        archiveCanisterId: ?Principal;
    };

    type UserData = {
        var amountAddCheckbox: ?Float;
        var amountAddInput: ?Float;
        var tokens: [Token];
    };

    transient var principalMap = Map.Make<Principal>(Principal.compare);
    stable var userData = principalMap.empty<UserData>();

    // Initialize default tokens for new users
    private func defaultTokens() : [Token] {
        [
            {
                symbol = "ICP";
                name = "Internet Computer";
                canisterId = Principal.fromActor(ICPLedger);
                archiveCanisterId = null; // FIXME@P2
            }
        ]
    };

    public query({caller}) func getLimitAmounts(): async {amountAddCheckbox: ?Float; amountAddInput: ?Float} {
        onlyOwner(caller, "getLimitAmounts");

        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                {amountAddCheckbox = data.amountAddCheckbox; amountAddInput = data.amountAddInput};
            };
            case (_) {
                {amountAddCheckbox = ?10.0; amountAddInput = ?30.0};
            };
        };
    };

    public shared({caller}) func setLimitAmounts(values: {amountAddCheckbox: ?Float; amountAddInput: ?Float}): async () {
        onlyOwner(caller, "setLimitAmounts");

        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.amountAddCheckbox := values.amountAddCheckbox;
                data.amountAddInput := values.amountAddInput;
            };
            case null {
                userData := principalMap.put<UserData>(
                    userData,
                    caller,
                    {
                        var amountAddCheckbox = ?10.0;
                        var amountAddInput = ?30.0;
                        var tokens = defaultTokens();
                    });
            };
        };
    };

    public query({caller}) func getTokens(): async [Token] {
        onlyOwner(caller, "getTokens");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) { data.tokens };
            case null { defaultTokens() };
        };
    };

    // FIXME@P2: Disallow adding the same token twice.
    public shared({caller}) func addToken(token: Token): async () {
        onlyOwner(caller, "addToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.append(data.tokens, [token]);
            };
            case null {
                userData := principalMap.put<UserData>(
                    userData,
                    caller,
                    {
                        var amountAddCheckbox = ?10.0; // FIXME@P2: duplicate data
                        var amountAddInput = ?30.0;
                        var tokens = Array.append(defaultTokens(), [token]);
                    });
            };
        };
    };

    // TODO@P1: Filter by principal, not symbol.
    public shared({caller}) func removeToken(symbol: Text): async () {
        onlyOwner(caller, "removeToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.filter(data.tokens, func(t: Token): Bool {
                    t.symbol != symbol
                });
            };
            case null { /* Do nothing */ };
        };
    };

    public shared({caller}) func addArchiveCanister(symbol: Text, archiveCanisterId: Principal): async () {
        onlyOwner(caller, "addArchiveCanister");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.map(data.tokens, func(t: Token): Token {
                    if (t.symbol == symbol) {
                        {t with archiveCanisterId = ?archiveCanisterId}
                    } else {
                        t
                    }
                });
            };
            case null { /* Do nothing */ };
        };
    };

    public query func getUserWallet(user: Principal): async {owner: Principal; subaccount: ?Blob} {
        // onlyOwner(caller, "getUserWallet");

        let canister = Principal.fromActor(this);
        {owner = canister; subaccount =
            if (Principal.isAnonymous(owner)) {
                ?(AccountID.principalToSubaccount(user));
            } else {
                null;
            }
        };
    };

    public query func getUserWalletText(user: Principal): async Text {
        // onlyOwner(caller, "getUserWallet");

        let canister = Principal.fromActor(this);
        if (Principal.isAnonymous(owner)) {
            let subaccount = ?(AccountID.principalToSubaccount(user));
            Account.toText({owner = canister; subaccount});
        } else {
            Principal.toText(canister);
        }
    };

    // query func isPersonalWallet(): async Bool {
    //     not owner.isAnonymous();
    // };

    public shared({caller}) func do_icrc1_transfer(token: ICRC1.Service, args: ICRC1.TransferArgs): async ICRC1.TransferResult {
        onlyOwner(caller, "do_icrc1_transfer");

        await token.icrc1_transfer(args);
    };

  /// Dividents and Withdrawals ///

  // FIXME@P1: Check whether the below code is correct even in the case, if the total amount of the PST is changeable.

  var totalDividends = 0;
  var totalDividendsPaid = 0; // actually paid sum
  // TODO: Set a heavy transfer fee of the PST to ensure that `lastTotalDivedends` doesn't take much memory.
  stable var lastTotalDivedends: BTree.BTree<Principal, Nat> = BTree.init<Principal, Nat>(null);

  func _dividendsOwing(_account: Principal): async Nat {
    let lastTotal = switch (BTree.get(lastTotalDivedends, Principal.compare, _account)) {
      case (?value) { value };
      case (null) { 0 };
    };
    let _newDividends = Int.abs((totalDividends: Int) - lastTotal);
    // rounding down
    let balance = await PST.icrc1_balance_of({owner = _account; subaccount = null});
    let total = await PST.icrc1_total_supply();
    balance * _newDividends / total;
  };

  func recalculateShareholdersDebt(_amount: Nat, _buyerAffiliate: ?Principal, _sellerAffiliate: ?Principal) {
    // Affiliates are delivered by frontend.
    // address payable _buyerAffiliate = affiliates[msg.sender];
    // address payable _sellerAffiliate = affiliates[_author];
    var _shareHoldersAmount = _amount;
    switch (_buyerAffiliate) {
      case (?_buyerAffiliate) {
        let _buyerAffiliateAmount = Int.abs(Fractions.mul(_amount, buyerAffiliateShare));
        indebt(_buyerAffiliate, _buyerAffiliateAmount);
        if (_shareHoldersAmount < _buyerAffiliateAmount) {
          Debug.trap("negative amount to pay");
        };
        _shareHoldersAmount -= _buyerAffiliateAmount;
      };
      case (null) {};
    };
    switch (_sellerAffiliate) {
      case (?_sellerAffiliate) {
        let _sellerAffiliateAmount = Int.abs(Fractions.mul(_amount, sellerAffiliateShare));
        indebt(_sellerAffiliate, _sellerAffiliateAmount);
        if (_shareHoldersAmount < _sellerAffiliateAmount) {
          Debug.trap("negative amount to pay");
        };
        _shareHoldersAmount -= _sellerAffiliateAmount;
      };
      case (null) {};
    };
    totalDividends += _shareHoldersAmount;
  };

  /// Outgoing Payments ///

  type OutgoingPayment = {
    amount: ICRC1Types.Balance;
    var time: ?Time.Time;
  };

  public shared({caller}) func payout(subaccount: ?ICRC1Types.Subaccount) {
    switch (BTree.get<Principal, OutgoingPayment>(ourDebts, Principal.compare, caller)) {
      case (?payment) {
        let time = switch (payment.time) {
          case (?time) { time };
          case (null) {
            let time = Time.now();
            payment.time := ?time;
            time;
          }
        };
        let fee = await ledger.icrc1_fee();
        let result = await ledger.icrc1_transfer({
          from_subaccount = null;
          to = {owner = caller; subaccount = subaccount};
          amount = payment.amount - fee;
          fee = null;
          memo = null;
          created_at_time = ?Nat64.fromNat(Int.abs(time)); // idempotent
        });
        ignore BTree.delete<Principal, OutgoingPayment>(ourDebts, Principal.compare, caller);
      };
      case (null) {};
    };
  };
};