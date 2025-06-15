import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";

import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Float "mo:base/Float";

import CertifiedData "mo:base/CertifiedData";
import CertTree "mo:cert/CertTree";

import ICRC1 "mo:icrc1-mo/ICRC1";
import ICRC2 "mo:icrc2-mo/ICRC2";
import ICRC3 "mo:icrc3-mo/";
import ICRC4 "mo:icrc4-mo/ICRC4";

import ICPLedger "canister:nns-ledger";
import Common "../common";
import env "mo:env";

type InitArgs = {
  icrc1 : ?ICRC1.InitArgs;
  icrc2 : ?ICRC2.InitArgs;
  icrc3 : ICRC3.InitArgs;
  icrc4 : ?ICRC4.InitArgs;
};

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

private func default_icrc3() : ICRC3.InitArgs {
  ?{
    maxActiveRecords = 3000;
    settleToRecords = 2000;
    maxRecordsInArchiveInstance = 100000000;
    maxArchivePages = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 8000;
    archiveCycles = 20_000_000_000_000;
    archiveControllers = null;
    supportedBlocks = [
      { block_type = "1xfer";   url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3" },
      { block_type = "2xfer";   url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3" },
      { block_type = "2approve"; url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3" },
      { block_type = "1mint";   url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3" },
      { block_type = "1burn";   url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3" }
    ];
  }
};

private func default_icrc4() : ICRC4.InitArgs {
  { max_balances = ?200; max_transfers = ?200; fee = ?#ICRC1 }
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

private func compute_icrc3(a : ?InitArgs) : ICRC3.InitArgs {
  switch(a){
    case(null) default_icrc3();
    case(?args){
      switch(args.icrc3){
        case(null) default_icrc3();
        case(?val) ?val;
      };
    };
  }
};

private func compute_icrc4(a : ?InitArgs) : ICRC4.InitArgs {
  switch(a){
    case(null) default_icrc4();
    case(?args){
      switch(args.icrc4){
        case(null) default_icrc4();
        case(?val) val;
      };
    };
  }
};

shared ({ caller = _owner }) actor class Token  (args : ?InitArgs) = this{

    let icrc1_args : ICRC1.InitArgs = compute_icrc1(args, _owner);
    let icrc2_args : ICRC2.InitArgs = compute_icrc2(args);
    let icrc3_args : ICRC3.InitArgs = compute_icrc3(args);
    let icrc4_args : ICRC4.InitArgs = compute_icrc4(args);

    stable let icrc1_migration_state = ICRC1.init(ICRC1.initialState(), #v0_1_0(#id),?icrc1_args, _owner);
    stable let icrc2_migration_state = ICRC2.init(ICRC2.initialState(), #v0_1_0(#id),?icrc2_args, _owner);
    stable let icrc4_migration_state = ICRC4.init(ICRC4.initialState(), #v0_1_0(#id),?icrc4_args, _owner);
    stable let icrc3_migration_state = ICRC3.init(ICRC3.initialState(), #v0_1_0(#id), icrc3_args, _owner);
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
      add_ledger_transaction = ?icrc3().add_record;
      can_transfer = null; //set to a function to intercept and add validation logic for transfers
    };
  };

    func icrc1() : ICRC1.ICRC1 {
    switch(_icrc1){
      case(null){
        let initclass : ICRC1.ICRC1 = ICRC1.ICRC1(?icrc1_migration_state, Principal.fromActor(this), get_icrc1_environment());
        ignore initclass.register_supported_standards({
          name = "ICRC-3";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-3/"
        });
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

  let #v0_1_0(#data(icrc4_state_current)) = icrc4_migration_state;

  private var _icrc4 : ?ICRC4.ICRC4 = null;

  private func get_icrc4_state() : ICRC4.CurrentState {
    return icrc4_state_current;
  };

  private func get_icrc4_environment() : ICRC4.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
      can_approve = null; //set to a function to intercept and add validation logic for approvals
      can_transfer_from = null; //set to a function to intercept and add validation logic for transfer froms
    };
  };

  func icrc4() : ICRC4.ICRC4 {
    switch(_icrc4){
      case(null){
        let initclass : ICRC4.ICRC4 = ICRC4.ICRC4(?icrc4_migration_state, Principal.fromActor(this), get_icrc4_environment());
        _icrc4 := ?initclass;
        initclass;
      };
      case(?val) val;
    };
  };

  let #v0_1_0(#data(icrc3_state_current)) = icrc3_migration_state;

  private var _icrc3 : ?ICRC3.ICRC3 = null;

  private func get_icrc3_state() : ICRC3.CurrentState {
    return icrc3_state_current;
  };

  func get_state() : ICRC3.CurrentState{
    return icrc3_state_current;
  };

  private func get_icrc3_environment() : ICRC3.Environment {
    ?{
      updated_certification = ?updated_certification;
      get_certificate_store = ?get_certificate_store;
    };
  };

  func ensure_block_types(icrc3Class: ICRC3.ICRC3) : () {
    let supportedBlocks = Buffer.fromIter<ICRC3.BlockType>(icrc3Class.supported_block_types().vals());

    let blockequal = func(a : {block_type: Text}, b : {block_type: Text}) : Bool {
      a.block_type == b.block_type;
    };

    if(Buffer.indexOf<ICRC3.BlockType>({block_type = "1xfer"; url="";}, supportedBlocks, blockequal) == null){
      supportedBlocks.add({
            block_type = "1xfer"; 
            url="https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
          });
    };

    if(Buffer.indexOf<ICRC3.BlockType>({block_type = "2xfer"; url="";}, supportedBlocks, blockequal) == null){
      supportedBlocks.add({
            block_type = "2xfer"; 
            url="https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
          });
    };

    if(Buffer.indexOf<ICRC3.BlockType>({block_type = "2approve";url="";}, supportedBlocks, blockequal) == null){
      supportedBlocks.add({
            block_type = "2approve"; 
            url="https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
          });
    };

    if(Buffer.indexOf<ICRC3.BlockType>({block_type = "1mint";url="";}, supportedBlocks, blockequal) == null){
      supportedBlocks.add({
            block_type = "1mint"; 
            url="https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
          });
    };

    if(Buffer.indexOf<ICRC3.BlockType>({block_type = "1burn";url="";}, supportedBlocks, blockequal) == null){
      supportedBlocks.add({
            block_type = "1burn"; 
            url="https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
          });
    };

    icrc3Class.update_supported_blocks(Buffer.toArray(supportedBlocks));
  };

  func icrc3() : ICRC3.ICRC3 {
    switch(_icrc3){
      case(null){
        let initclass : ICRC3.ICRC3 = ICRC3.ICRC3(?icrc3_migration_state, Principal.fromActor(this), get_icrc3_environment());
        _icrc3 := ?initclass;
        ensure_block_types(initclass);

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

      switch( await* icrc1().mint_tokens(caller, args)){
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

  public query func icrc3_get_blocks(args: ICRC3.GetBlocksArgs) : async ICRC3.GetBlocksResult{
    return icrc3().get_blocks(args);
  };

  public query func icrc3_get_archives(args: ICRC3.GetArchivesArgs) : async ICRC3.GetArchivesResult{
    return icrc3().get_archives(args);
  };

  public query func icrc3_get_tip_certificate() : async ?ICRC3.DataCertificate {
    return icrc3().get_tip_certificate();
  };

  public query func icrc3_supported_block_types() : async [ICRC3.BlockType] {
    return icrc3().supported_block_types();
  };

  public query func get_tip() : async ICRC3.Tip {
    return icrc3().get_tip();
  };

  public shared ({ caller }) func icrc4_transfer_batch(args: ICRC4.TransferBatchArgs) : async ICRC4.TransferBatchResults {
      switch(await* icrc4().transfer_batch_tokens(caller, args, null, null)){
        case(#trappable(val)) val;
        case(#awaited(val)) val;
        case(#err(#trappable(err))) err;
        case(#err(#awaited(err))) err;
      };
  };

  public shared query func icrc4_balance_of_batch(request : ICRC4.BalanceQueryArgs) : async ICRC4.BalanceQueryResult {
      icrc4().balance_of_batch(request);
  };

  public shared query func icrc4_maximum_update_batch_size() : async ?Nat {
      ?icrc4().get_state().ledger_info.max_transfers;
  };

  public shared query func icrc4_maximum_query_batch_size() : async ?Nat {
      ?icrc4().get_state().ledger_info.max_balances;
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

  public shared ({ caller }) func admin_update_icrc4(requests : [ICRC4.UpdateLedgerInfoRequest]) : async [Bool] {
    if(caller != owner){ D.trap("Unauthorized")};
    return icrc4().update_ledger_info(requests);
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
      let test4 = icrc4().metadata();
      let test3 = icrc3().stats();

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

    /// Buy ICPACK with ICP transferred to the caller's subaccount.
    ///
    /// The amount of tokens minted is determined by integrating a price curve
    /// over the caller's investment.  Initially, each ICP buys 4/3 ICPACK.  At
    /// 16,666.66 ICP invested in total the rate drops to half that, and after
    /// about twice that amount of ICPACK has been bought the cost grows without bound.  The
    /// integral ensures that investing 16,666.66 ICP mints exactly the same
    /// amount of ICPACK while early investors receive proportionally more.
    public shared({caller = user}) func buyWithICP() : async ICRC1.TransferResult {
        // FIXME@P1: Ensure that token exchange is reliable.
        let subaccount = Common.principalToSubaccount(user);
        let icpBalance = await ICPLedger.icrc1_balance_of({
            owner = Principal.fromActor(this);
            subaccount = ?subaccount;
        });
        if (icpBalance <= 2 * Common.icp_transfer_fee) {
            return #Err(#GenericError{ error_code = 0; message = "no ICP" });
        };
        let invest = icpBalance - Common.icp_transfer_fee;
        switch(await ICPLedger.icrc1_transfer({
            to = { owner = Principal.fromActor(this); subaccount = null };
            fee = null;
            memo = null;
            from_subaccount = ?subaccount;
            created_at_time = null;
            amount = invest;
        })) {
            case (#Err e) { return #Err e };
            case (#Ok _) {};
        };

        //
        // The number of PST tokens minted for an ICP investment is given by
        // integrating a price curve which gradually increases the cost of a token
        // as more ICP is invested.  The shape of the curve is chosen so that:
        //   * investing 16,666.66 ICP in total results in 16,666.66 newly minted
        //     ICPACK tokens (one token per ICP on average);
        //   * at the very beginning the buyer receives twice as many ICPACK per
        //     ICP as at the 16,666.66 ICP mark; and
        //   * once about twice that amount of ICPACK (33,333.32 ICPACK) has been
        //     bought, the price tends to infinity and no new ICPACK can be purchased.
        //
        // These conditions are satisfied when the instantaneous number of
        // ICPACK tokens obtainable for one ICP depends linearly on the total
        // number of ICPACK already minted, `g(m) = 4/3 * (1 - m/L)` where `L`
        // is twice 16,666.66 ICPACK expressed in e8s.  Integrating this
        // expression yields a curve that approaches `L` tokens as the required
        // investment tends to infinity.

        let limitTokens = 3_333_332_000_000; // ~33,333.32 ICPACK in e8s

        let limitF = Float.fromInt(limitTokens);
        let prevMintedF = Float.fromInt(totalMinted);
        let investF = Float.fromInt(invest);

        let newMintedF = limitF - (limitF - prevMintedF) * Float.exp(-4.0 * investF / (3.0 * limitF));
        if (newMintedF > limitF) {
            return #Err(#GenericError{ error_code = 1; message = "investment overflow" });
        };
        let mintedF = newMintedF - prevMintedF;
        let mintedInt = Int.abs(Float.toInt(mintedF));
        let minted : Nat = Int.abs(mintedInt);
        totalInvested += invest;
        totalMinted += Int.abs(Float.toInt(newMintedF - prevMintedF));

        let mintResult = await this.mint({
            to = { owner = user; subaccount = null };
            amount = minted;
            memo = null;
            created_at_time = null;
        });

        switch (mintResult) {
            case (#Err e) { return #Err e };
            case (#Ok _) {
                switch(await ICPLedger.icrc1_transfer({
                    to = { owner = revenueRecipient; subaccount = null };
                    fee = null;
                    memo = null;
                    from_subaccount = null;
                    created_at_time = null;
                    amount = invest - Common.icp_transfer_fee;
                })) {
                    case (#Err e2) { return #Err e2 };
                    case (#Ok _) {};
                };
                mintResult;
            };
        };
    };
}