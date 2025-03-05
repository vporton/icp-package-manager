import Cycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Map "mo:base/OrderedMap";

module {
  public type CanisterFulfillment = {
    threshold: Nat;
    installAmount: Nat;
  };

  public type CanisterKind = Text;

  public type CanisterMap = Map.Map<Principal, CanisterKind>;

  public type CanisterKindsMap = Map.Map<CanisterKind, CanisterFulfillment>;

  /// Battery API ///

  public type Battery = {
    defaultFulfillment: CanisterFulfillment;
    canisterMap: CanisterMap;
    canisterKindsMap: CanisterKindsMap;
  };

  public func newBattery(): Battery {
    {
      canisterMap = OrderedMap.init<Principal, CanisterKind>();
      canisterKindsMap = OrderedMap.init<CanisterKind, CanisterFulfillment>();
    };
  };

  private func canisterKindEqual(a: CanisterKind, b: CanisterKind): Bool = a == b;

  private func canisterKindHash(x: CanisterKind): Hash.Hash = Text.hash(x);

  public func topUpOneCanister(battery: Battery, canisterId: Principal): async* () {
    let kind = OrderedMap.get(battery.canisterMap, Principal.equal, Principal.hash, canisterId);
    let info0 = do ? { OrderedMap.get(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind!)! };
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
    for (canisterId in OrderedMap.keys(battery.canisterMap)) {
      await* topUpOneCanister(battery, canisterId);
    };
  };

  public func addCanister(battery: Battery, canisterId: Principal, kind: Text) {
    OrderedMap.put(battery.canisterMap, Principal.equal, Principal.hash, canisterId, kind);
  };

  public func insertCanisterKind(battery: Battery, kind: Text, info: CanisterFulfillment) {
    OrderedMap.put(battery.canisterKindsMap, canisterKindEqual, canisterKindHash, kind, info);
  };

  /// ChildActor API ///

  public func askForCycles(batteryPrincipal: Principal, needy: Principal, threshold: Nat): async* () {
    if (Cycles.available() < threshold) {
      let battery: BatteryActor = actor(Principal.toText(batteryPrincipal));
      await battery.cycles_simple_provideCycles(needy);
    };
  };
};
