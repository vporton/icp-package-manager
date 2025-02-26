import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Error "mo:base/Error";
import StableHashMap "mo:stablehashmap/FunctionalStableHashMap";

module {
  public type CanisterFulfillmentInfo = {
    threshold: Nat;
    installAmount: Nat;
  };

  /// It makes sense to provide only, if the battery is controlled by childs.
  public type BatteryActor = actor {
    cycles_simple_provideCycles: query (needy: Principal) -> async ();
  };

  public type ChildActor = actor {
    cycles_simple_availableCycles: query () -> async Nat;
  };

  public type CanisterKind = Text;

  public type CanisterMap = StableHashMap.StableHashMap<Principal, CanisterKind>;

  public type CanisterKindsMap = StableHashMap.StableHashMap<CanisterKind, CanisterFulfillmentInfo>;

  /// Battery API ///

  public type Battery = {
    canisterMap: CanisterMap;
    canisterKindsMap: CanisterKindsMap;
  };

  public func newBattery(): Battery {
    {
      canisterMap = StableHashMap.init<Principal, CanisterKind>();
      canisterKindsMap = StableHashMap.init<CanisterKind, CanisterFulfillmentInfo>();
    };
  };

  private func canisterKindEqual(a: CanisterKind, b: CanisterKind): Bool = a == b;

  private func canisterKindHash(x: CanisterKind): Hash.Hash = Text.hash(x);

  public func topUpOneCanister(battery: Battery, canisterId: Principal): async* () {
    let kind = StableHashMap.get(battery.canisterMap, Principal.equal, Principal.hash, canisterId);
    let info0 = do ? { StableHashMap.get(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind!)! };
    let ?info = info0 else {
      Debug.trap("no such canister record");
    };
    let child: ChildActor = actor(Principal.toText(canisterId));
    let remaining = try {
      await child.cycles_simple_availableCycles();
    }
    catch(e) {
      // switch (Error.code(e)) {
      //   case (#call_error {err_code = 0}) {
      if (not Text.contains(Error.message(e), #text "out of cycles")) {
        return;
      };
      //   };
      //   case _ {
      //     return;
      //   };
      // };
      0;
    };
    if (remaining <= info.threshold) {
      Cycles.add<system>(info.installAmount);
      let ic : actor {
        deposit_cycles : shared { canister_id : Principal } -> async ();
      } = actor ("aaaaa-aa");
      await ic.deposit_cycles({canister_id = canisterId});
    };
  };

  public func topUpAllCanisters(battery: Battery): async* () {
    for (canisterId in StableHashMap.keys(battery.canisterMap)) {
      await* topUpOneCanister(battery, canisterId);
    };
  };

  public func addCanister(battery: Battery, canisterId: Principal, kind: Text) {
    StableHashMap.put(battery.canisterMap, Principal.equal, Principal.hash, canisterId, kind);
  };

  public func insertCanisterKind(battery: Battery, kind: Text, info: CanisterFulfillmentInfo) {
    StableHashMap.put(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind, info);
  };

  /// ChildActor API ///

  public func askForCycles(batteryPrincipal: Principal, needy: Principal, threshold: Nat): async* () {
    if (Cycles.available() < threshold) {
      let battery: BatteryActor = actor(Principal.toText(batteryPrincipal));
      await battery.cycles_simple_provideCycles(needy);
    };
  };
};
