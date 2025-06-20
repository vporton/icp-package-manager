import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";

import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";

import CertifiedData "mo:base/CertifiedData";
import Array "mo:base/Array";
import CertTree "mo:cert/CertTree";

import ICRC1 "mo:icrc1-mo/ICRC1";
import ICRC2 "mo:icrc2-mo/ICRC2";
import Sha256 "mo:sha2/Sha256";
import Map "mo:base/OrderedMap";

import ICPLedger "canister:nns-ledger";
import Account "../lib/Account";
import Common "../common";
import env "mo:env";

shared ({ caller = _owner }) actor class Token  (args : ?{
    icrc1 : ?ICRC1.InitArgs;
    icrc2 : ?ICRC2.InitArgs;
}) = this{
  type InitArgs = {
    icrc1 : ?ICRC1.InitArgs;
    icrc2 : ?ICRC2.InitArgs;
  };

  let recipientAccount = Principal.fromText(env.revenueRecipient);

  private func default_icrc1(owner : Principal) : ICRC1.InitArgs {
    {
      name = ?"Test Token";
      symbol = ?"TTT";
      logo = ?"data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMSIgaGVpZ2h0PSIxIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InJlZCIvPjwvc3ZnPg==";
      decimals = 8;
      fee = ?#Fixed(10000);
      minting_account = ?{ owner = owner; subaccount = null };
      max_supply = null;
      min_burn_amount = ?10000;
      max_memo = ?64;
      advanced_settings = null;
      metadata = null;
      fee_collector = null;
      transaction_window = null;
      permitted_drift = null;
      max_accounts = ?100000000;
      settle_to_accounts = ?99999000;
    }
  };

  private func default_icrc2() : ICRC2.InitArgs {
    {
      max_approvals_per_account = ?10000;
      max_allowance = ?#TotalSupply;
      fee = ?#ICRC1;
      advanced_settings = null;
      max_approvals = ?10000000;
      settle_to_approvals = ?9990000;
    }
  };

  private func compute_icrc1(a : ?InitArgs, owner : Principal) : ICRC1.InitArgs {
    switch(a){
      case(null) default_icrc1(owner);
      case(?args){
        switch(args.icrc1){
          case(null) default_icrc1(owner);
          case(?val){
            {
              val with minting_account = switch(val.minting_account){
                case(?v) ?v;
                case(null) ?{ owner = owner; subaccount = null };
              };
            };
          };
        };
      };
    }
  };

  private func compute_icrc2(a : ?InitArgs) : ICRC2.InitArgs {
    switch(a){
      case(null) default_icrc2();
      case(?args){
        switch(args.icrc2){
          case(null) default_icrc2();
          case(?val) val;
        };
      };
    }
  };

    let icrc1_args : ICRC1.InitArgs = compute_icrc1(args, _owner);
    let icrc2_args : ICRC2.InitArgs = compute_icrc2(args);

    stable let icrc1_migration_state = ICRC1.init(ICRC1.initialState(), #v0_1_0(#id),?icrc1_args, _owner);
    stable let icrc2_migration_state = ICRC2.init(ICRC2.initialState(), #v0_1_0(#id),?icrc2_args, _owner);
    stable let cert_store : CertTree.Store = CertTree.newStore();
    let ct = CertTree.Ops(cert_store);


    stable var owner = _owner;

    let #v0_1_0(#data(icrc1_state_current)) = icrc1_migration_state;

    private var _icrc1 : ?ICRC1.ICRC1 = null;

    private func get_icrc1_state() : ICRC1.CurrentState {
      return icrc1_state_current;
    };

    private func get_icrc1_environment() : ICRC1.Environment {
    {
      get_time = null;
      get_fee = null;
      add_ledger_transaction = null;
      // can_transfer = null; //set to a function to intercept and add validation logic for transfers
    };
  };

    func icrc1() : ICRC1.ICRC1 {
    switch(_icrc1){
      case(null){
        let initclass : ICRC1.ICRC1 = ICRC1.ICRC1(?icrc1_migration_state, Principal.fromActor(this), get_icrc1_environment());
        ignore initclass.register_supported_standards({
          name = "ICRC-10";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-10/"
        });
        _icrc1 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };

  let #v0_1_0(#data(icrc2_state_current)) = icrc2_migration_state;

  private var _icrc2 : ?ICRC2.ICRC2 = null;

  private func get_icrc2_state() : ICRC2.CurrentState {
    return icrc2_state_current;
  };

  private func get_icrc2_environment() : ICRC2.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
      can_approve = null; //set to a function to intercept and add validation logic for approvals
      can_transfer_from = null; //set to a function to intercept and add validation logic for transfer froms
    };
  };

  func icrc2() : ICRC2.ICRC2 {
    switch(_icrc2){
      case(null){
        let initclass : ICRC2.ICRC2 = ICRC2.ICRC2(?icrc2_migration_state, Principal.fromActor(this), get_icrc2_environment());
        _icrc2 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };

  private func updated_certification(cert: Blob, lastIndex: Nat) : Bool{

    // D.print("updating the certification " # debug_show(CertifiedData.getCertificate(), ct.treeHash()));
    ct.setCertifiedData();
    // D.print("did the certification " # debug_show(CertifiedData.getCertificate()));
    return true;
  };

  private func get_certificate_store() : CertTree.Store {
    // D.print("returning cert store " # debug_show(cert_store));
    return cert_store;
  };

  /// Functions for the ICRC1 token standard
  public shared query func icrc1_name() : async Text {
      icrc1().name();
  };

  public shared query func icrc1_symbol() : async Text {
      icrc1().symbol();
  };

  public shared query func icrc1_decimals() : async Nat8 {
      icrc1().decimals();
  };

  public shared query func icrc1_fee() : async ICRC1.Balance {
      icrc1().fee();
  };

  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
      icrc1().metadata()
  };

  public shared query func icrc1_total_supply() : async ICRC1.Balance {
      icrc1().total_supply();
  };

  public shared query func icrc1_minting_account() : async ?ICRC1.Account {
      ?icrc1().minting_account();
  };

  public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
      icrc1().balance_of(args);
  };

  public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
      icrc1().supported_standards();
  };

  public shared query func icrc10_supported_standards() : async [ICRC1.SupportedStandard] {
      icrc1().supported_standards();
  };

  public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
      switch(await* icrc1().transfer_tokens(caller, args, false, null)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) D.trap(err);
        case(#err(#awaited(err))) D.trap(err);
      };
  };

  public shared ({ caller }) func mint(args : ICRC1.Mint) : async ICRC1.TransferResult {
      if(caller != owner){ D.trap("Unauthorized")};

      let nowTs = Nat64.fromNat(Int.abs(Time.now()));
      let mintArgs : ICRC1.Mint = {
        args with created_at_time = switch(args.created_at_time){
          case(null) ?nowTs;
          case(?t) ?t;
        }
      };

      switch( await* icrc1().mint_tokens(caller, mintArgs)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) D.trap(err);
        case(#err(#awaited(err))) D.trap(err);
      };
  };

  public shared ({ caller }) func burn(args : ICRC1.BurnArgs) : async ICRC1.TransferResult {
      switch( await*  icrc1().burn_tokens(caller, args, false)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) D.trap(err);
        case(#err(#awaited(err))) D.trap(err);
      };
  };

   public query ({ caller }) func icrc2_allowance(args: ICRC2.AllowanceArgs) : async ICRC2.Allowance {
      return icrc2().allowance(args.spender, args.account, false);
    };

  public shared ({ caller }) func icrc2_approve(args : ICRC2.ApproveArgs) : async ICRC2.ApproveResponse {
      switch(await*  icrc2().approve_transfers(caller, args, false, null)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) D.trap(err);
        case(#err(#awaited(err))) D.trap(err);
      };
  };

  public shared ({ caller }) func icrc2_transfer_from(args : ICRC2.TransferFromArgs) : async ICRC2.TransferFromResponse {
      switch(await* icrc2().transfer_tokens_from(caller, args, null)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) D.trap(err);
        case(#err(#awaited(err))) D.trap(err);
      };
  };

  public shared ({ caller }) func admin_update_owner(new_owner : Principal) : async Bool {
    if(caller != owner){ D.trap("Unauthorized")};
    owner := new_owner;
    return true;
  };

  public shared ({ caller }) func admin_update_icrc1(requests : [ICRC1.UpdateLedgerInfoRequest]) : async [Bool] {
    if(caller != owner){ D.trap("Unauthorized")};
    return icrc1().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc2(requests : [ICRC2.UpdateLedgerInfoRequest]) : async [Bool] {
    if(caller != owner){ D.trap("Unauthorized")};
    return icrc2().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_clear_stale_finish_buy_locks() : async Nat {
    if(caller != owner){ D.trap("Unauthorized")};
    let now = Nat64.fromNat(Int.abs(Time.now()));
    return cleanupFinishBuyLocks(now);
  };

  public shared ({ caller }) func admin_clear_stale_token_to_deliver() : async Nat {
    if(caller != owner){ D.trap("Unauthorized")};
    let now = Nat64.fromNat(Int.abs(Time.now()));
    return cleanupTokenToDeliver(now);
  };

  /* /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_listener(trx: ICRC1.Transaction, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func approval_listener(trx: ICRC2.TokenApprovalNotification, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_from_listener(trx: ICRC2.TransferFromNotification, trxid: Nat) : () {

  }; */

  private stable var _init = false;
  public shared(msg) func admin_init() : async () {
    //can only be called once


    if(_init == false){
      //ensure metadata has been registered
      let test1 = icrc1().metadata();
      let test2 = icrc2().metadata();

      //uncomment the following line to register the transfer_listener
      //icrc1().register_token_transferred_listener<system>("my_namespace", transfer_listener);

      //uncomment the following line to register the transfer_listener
      //icrc2().register_token_approved_listener<system>("my_namespace", approval_listener);

      //uncomment the following line to register the transfer_listener
      //icrc2().register_transfer_from_listener<system>("my_namespace", transfer_from_listener);
    };
    _init := true;
  };


  // Deposit cycles into this canister.
  public shared func deposit_cycles() : async () {
      let amount = ExperimentalCycles.available();
      let accepted = ExperimentalCycles.accept<system>(amount);
      assert (accepted == amount);
  };

  system func postupgrade() {
    //re wire up the listener after upgrade
    //uncomment the following line to register the transfer_listener
      //icrc1().register_token_transferred_listener("my_namespace", transfer_listener);

      //uncomment the following line to register the transfer_listener
      //icrc2().register_token_approved_listener("my_namespace", approval_listener);

      //uncomment the following line to register the transfer_listener
      //icrc2().register_transfer_from_listener("my_namespace", transfer_from_listener);
  };

    /// Investment code ///

    /// Total invested ICP in e8s.
    stable var totalInvested : Nat = 0;
    /// Total ICPACK tokens minted via investments.
    stable var totalMinted : Nat = 0;

    transient let revenueRecipient = Principal.fromText(env.revenueRecipient);

    /// A temporary account to put investment to before it is finally withdrawn.
    private func accountWithInvestment(user: Principal): Account.Account {
      let random: Blob = "\e9\ad\41\82\0f\f5\01\db\08\7a\11\1f\97\8e\d6\9b\16\db\55\70\25\d6\e3\ce\a0\76\04\cb\a6\3c\ef\c5"; // unique 256 bit
      let randomArray = Blob.toArray(random);
      let binPrincipal = Principal.toBlob(user);
      let principalArray = Blob.toArray(binPrincipal);
      let joined = Array.tabulate(
        32 + Array.size(principalArray),
        func (i: Nat): Nat8 = if (i < 32) { randomArray[i] } else { principalArray[i-32] }
      );
      let subaccount = Sha256.fromBlob(#sha256, Blob.fromArray(joined));
      { owner = Principal.fromActor(this); subaccount = ?subaccount };
    };

    /// Buy ICPACK with ICP transferred to the caller's subaccount.
    ///
    /// The amount of tokens minted is determined by integrating a price curve
    /// over the caller's investment. Initially, each ICP buys 4/3 ICPACK. At
    /// 16,666.66 ICP invested in total the rate drops to half that, and after
    /// about twice that amount of ICPACK has been bought the cost grows without
    /// bound. The integral ensures that investing 16,666.66 ICP mints exactly
    /// the same amount of ICPACK while early investors receive proportionally
    /// more.
    ///
    /// The number of PST tokens minted for an ICP investment is given by
    /// integrating a price curve which gradually increases the cost of a token
    /// as more ICP is invested. The shape of the curve is chosen so that:
    ///   * investing 16,666.66 ICP in total results in 16,666.66 newly minted
    ///     ICPACK tokens (one token per ICP on average);
    ///   * at the very beginning the buyer receives twice as many ICPACK per
    ///     ICP as at the 16,666.66 ICP mark; and
    ///   * once about twice that amount of ICPACK (33,333.32 ICPACK) has been
    ///     bought, the price tends to infinity and no new ICPACK can be
    ///     purchased.
    ///
    /// These conditions are satisfied when the instantaneous number of ICPACK
    /// tokens obtainable for one ICP depends linearly on the total number of
    /// ICPACK already minted, `g(m) = 4/3 * (1 - m/L)` where `L` is twice
    /// 16,666.66 ICPACK expressed in e8s. Integrating this expression yields a
    /// curve that approaches `L` tokens as the required investment tends to
    /// infinity.
    public shared({caller = user}) func buyWithICP(wallet: Principal, amount: Nat) : async ()/*ICRC1.TransferResult*/ { // TODO@P1: What should be the return type?
        if (wallet != user) {
            Debug.trap("wallet must equal caller");
        };
        await finishBuyWithICP(wallet); // settle possible previous attempt

        if (amount == 0) { return (); };

        var lock = ensureInvestmentLock(user);
        if (not lock.transferring) {
            let ts = if (lock.createdAtTime == 0) { Nat64.fromNat(Int.abs(Time.now())) } else { lock.createdAtTime };
            lock := {transferring = true; createdAtTime = ts};
            lockInvestAccount := principalMap.put(lockInvestAccount, user, lock);
        };

        switch(await ICPLedger.icrc1_transfer({
            to = accountWithInvestment(user);
            fee = null;
            memo = null;
            from_subaccount = ?Common.principalToSubaccount(user);
            created_at_time = ?lock.createdAtTime;
            amount;
        })) {
            case (#Ok _) {};
            case (#Err(#Duplicate _)) {};
            case (#Err e) {
                lockInvestAccount := principalMap.put(lockInvestAccount, user, {lock with transferring = false; createdAtTime = 0 : Nat64});
                return (); // FIXME@P1
            };
        };

        lockInvestAccount := principalMap.delete(lockInvestAccount, user);

        await finishBuyWithICP(wallet); // TODO@P3: Use `await*`. // FIXME@P1: `ignore`
        (); // FIXME@P1
    };

    transient let principalMap = Map.Make<Principal>(Principal.compare);

    public type InvestLock = {
        transferring: Bool;
        createdAtTime: Nat64;
    };

    private let emptyInvestLock : InvestLock = {transferring = false; createdAtTime = 0 : Nat64};

    /// Ongoing ICP transfer to the investment account.
    stable var lockInvestAccount = principalMap.empty<InvestLock>();

    /// Return the lock entry for a user or trap if it doesn't exist.
    private func investmentLock(user: Principal) : InvestLock {
        switch (principalMap.get(lockInvestAccount, user)) {
            case (?l) l;
            case null Debug.trap("investment lock missing");
        };
    };

    /// Ensure that a lock entry exists and return it.
    private func ensureInvestmentLock(user: Principal) : InvestLock {
        switch (principalMap.get(lockInvestAccount, user)) {
            case (?l) l;
            case null {
                lockInvestAccount := principalMap.put(lockInvestAccount, user, emptyInvestLock);
                emptyInvestLock
            };
        };
    };

    public type MintLock = {
        minted: Nat;
        invest: Nat;
        createdAtTime: Nat64;
        mintedDone: Bool; // set once the minting call succeeds
    };

    /// Ongoing PST purchase state per user.
    /// The entry persists until all transfers complete.
    stable var tokenToDeliver = principalMap.empty<MintLock>(); // FIXME@P1: Limit the storage.

    /// Users currently executing `finishBuyWithICP` with the timestamp when the
    /// lock was acquired.
    stable var finishBuyLock = principalMap.empty<Nat64>();
    private let finishBuyLockTimeout : Nat64 = 30 * 60 * 1_000_000_000; // 30 min
    private let tokenToDeliverTimeout : Nat64 = 24 * 60 * 60 * 1_000_000_000; // 1 day

    private func cleanupTokenToDeliver(now : Nat64) : Nat {
        var removed : Nat = 0;
        var i = tokenToDeliver.entries();
        loop {
            switch(i.next()) {
                case(null) break;
                case(?(u, lock)) {
                    if (lock.createdAtTime + tokenToDeliverTimeout < now) {
                        tokenToDeliver := principalMap.delete(tokenToDeliver, u);
                        removed += 1;
                    };
                };
            };
        };
        removed;
    };

    private func cleanupFinishBuyLocks(now : Nat64) : Nat {
        var removed : Nat = 0;
        var i = finishBuyLock.entries();
        loop {
            switch(i.next()) {
                case(null) break;
                case(?(u, ts)) {
                    if (ts + finishBuyLockTimeout < now) {
                        finishBuyLock := principalMap.delete(finishBuyLock, u);
                        removed += 1;
                    };
                };
            };
        };
        removed;
    };

    // TODO@P1: Reach reliability.
    // FIXME: Needs some rewrite.
    public shared({caller = user}) func finishBuyWithICP(wallet: Principal) : async ()/*ICRC1.TransferResult*/ { // TODO@P1: What should be the return type?
        if (wallet != user) {
            Debug.trap("wallet must equal caller");
        };
        let now = Nat64.fromNat(Int.abs(Time.now()));
        ignore cleanupFinishBuyLocks(now);
        ignore cleanupTokenToDeliver(now);
        if (principalMap.get(finishBuyLock, user) != null) {
            return (); // already running
        };
        finishBuyLock := principalMap.put(finishBuyLock, user, now);
        func release() {
            finishBuyLock := principalMap.delete(finishBuyLock, user);
        };
        var lock = switch (principalMap.get(tokenToDeliver, user)) {
          case (?l) l;
          case null {
            let investmentAccount = accountWithInvestment(user);
            let icpBalance = await ICPLedger.icrc1_balance_of(investmentAccount);
            if (icpBalance <= Common.icp_transfer_fee) {
                release();
                return (); // FIXME@P1
                // return #Err(#GenericError{ error_code = 0; message = "no ICP" });
            };
            let invest = icpBalance - Common.icp_transfer_fee;

            let limitTokens = 3_333_332_000_000; // ~33,333.32 ICPACK in e8s

            let limitF = Float.fromInt(limitTokens);
            let prevMintedF = Float.fromInt(totalMinted);
            let investF = Float.fromInt(invest);

            let newMintedF = limitF - (limitF - prevMintedF) * Float.exp(-4.0 * investF / (3.0 * limitF));
            if (newMintedF > limitF) {
                release();
                return; // #Err(#GenericError{ error_code = 1; message = "investment overflow" }); // FIXME: return value
            };
            let mintedF = newMintedF - prevMintedF;
            let mintedInt = Int.abs(Float.toInt(mintedF));
            let minted : Nat = Int.abs(mintedInt);
            let ts = Nat64.fromNat(Int.abs(Time.now()));
            let nl : MintLock = { minted; invest; createdAtTime = ts; mintedDone = false };
            tokenToDeliver := principalMap.put(tokenToDeliver, user, nl);
            nl;
          };
        };

        // Mint PST before performing any transfers if not done yet.
        let investmentAccount = accountWithInvestment(user);
        if (not lock.mintedDone) {
            // We don't use `await mint()` also because it's async and breaks reliability.
            let _ = switch (await* icrc1().mint_tokens(owner, {
              to = {owner = wallet; subaccount = ?(Common.principalToSubaccount(user))};
              amount = lock.minted;
              memo = null;
              created_at_time = ?lock.createdAtTime;
            })) {
              case(#trappable(val)) val;
              case(#awaited(val)) val;
              case(#err(#trappable(err))) {
                release();
                return (); // FIXME@P1
              };
              case(#err(#awaited(err))) {
                release();
                return (); // FIXME@P1
              };
            };
            lock := { lock with mintedDone = true };
            tokenToDeliver := principalMap.put(tokenToDeliver, user, lock);
        };

        // Transfer minted PST to the recipient account.
        let pstAccount = {
          owner = wallet;
          subaccount = ?(Common.principalToSubaccount(user));
        };
        if (icrc1().balance_of(pstAccount) > 0) {
          let transferRes = switch(await* icrc1().transfer_tokens(user, {
            memo = null;
            amount = lock.minted;
            fee = null;
            from_subaccount = pstAccount.subaccount;
            to = {owner = recipientAccount; subaccount = null};
            created_at_time = null;
          }, false, null)) {
            case(#trappable(val)) val;
            case(#awaited(val)) val;
            case(#err(#trappable(err))) {
              release();
              return (); // FIXME@P1
            };
            case(#err(#awaited(err))) {
              release();
              return (); // FIXME@P1
            };
          };
          switch(transferRes) {
            case (#Ok _) {};
            case (#Err(#Duplicate _)) {};
            case (#Err e) {
              release();
              return ();
            };
          };
          if (icrc1().balance_of(pstAccount) > 0) {
            release();
            return ();
          };
        };

        // Transfer invested ICP to the revenue recipient.
        let icpBalance = await ICPLedger.icrc1_balance_of(investmentAccount);
        if (icpBalance > Common.icp_transfer_fee) {
          switch(await ICPLedger.icrc1_transfer({
              to = { owner = revenueRecipient; subaccount = null };
              fee = null;
              memo = null;
              from_subaccount = investmentAccount.subaccount;
              created_at_time = ?lock.createdAtTime;
              amount = lock.invest;
          })) {
              case (#Ok _) {};
              case (#Err(#Duplicate _)) {};
              case (#Err e) {
                  release();
                  return ();
              };
          };
          let icpAfter = await ICPLedger.icrc1_balance_of(investmentAccount);
          if (icpAfter > Common.icp_transfer_fee) {
              release();
              return ();
          };
        };
        totalInvested += lock.invest;
        totalMinted += lock.minted;
        tokenToDeliver := principalMap.delete(tokenToDeliver, user);
        // Remove any investment lock since the invested ICP was drained
        // from the user's dedicated account. This prevents retries from
        // attempting `icrc1_transfer` again with stale timestamps.
        lockInvestAccount := principalMap.delete(lockInvestAccount, user);
        release();
        (); // FIXME@P1
    };
}