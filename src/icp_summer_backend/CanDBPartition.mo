import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import CA "mo:candb/CanisterActions";
import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import RBT "mo:stable-rbtree/StableRBTree";

shared ({ caller = owner }) actor class CanDBPartition({
  partitionKey: Text;
  scalingOptions: CanDB.ScalingOptions;
  owners: ?[Principal]
}) {
  private func onlyOwner(caller: Principal) {
    if (caller != owner) {
      Debug.trap("not an owner");
    }
  };

  /// @required (may wrap, but must be present in some form in the canister)
  ///
  /// Initialize CanDB
  stable let db = CanDB.init({
    pk = partitionKey;
    scalingOptions = scalingOptions;
    btreeOrder = null;
  });

  /// @recommended (not required) public API
  public query func getPK(): async Text { db.pk };

  /// @required public API (Do not delete or change)
  public shared({ caller = caller }) func transferCycles(): async () {
    onlyOwner(caller);
    await CA.transferCycles(caller);
  };

  /// @required public API (Do not delete or change)
  public query func skExists(sk: Text): async Bool { 
    CanDB.skExists(db, sk);
  };

  public query func get(sk: Text): async ?Entity.Entity { 
    CanDB.get(db, {sk});
  };

  public query func getAttribute(sk: Text, subkey: Text): async ?Entity.AttributeValue { 
    do ? { RBT.get<Text, Entity.AttributeValue>(CanDB.get(db, {sk})!.attributes, Text.compare, subkey)! };
  };

  public shared({caller}) func put(sk: Text, attributes: [(Entity.AttributeKey, Entity.AttributeValue)]): async () {
    onlyOwner(caller);
    await* CanDB.put(db, {sk; attributes});
  };

  public shared({caller}) func putAttribute(sk: Text, subkey: Entity.AttributeKey, attribute: Entity.AttributeValue): async () {
    onlyOwner(caller);
    ignore CanDB.update(db, { sk; updateAttributeMapFunction = func(old: ?Entity.AttributeMap): Entity.AttributeMap {
      let map = switch (old) {
        case (?old) { old };
        case null { RBT.init() };
      };
      RBT.put(map, Text.compare, subkey, attribute);
    }});
  };
}