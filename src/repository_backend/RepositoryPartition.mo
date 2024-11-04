import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import CA "mo:candb/CanisterActions";
import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import RBT "mo:stable-rbtree/StableRBTree";
import Itertools "mo:itertools/Iter";
import Common "../common";

shared ({ caller = owner }) actor class RepositoryPartition({
  partitionKey: Text;
  scalingOptions: CanDB.ScalingOptions;
  owners: [Principal]
}) = this {
  // CanDB paritition methods //

  private func onlyOwner(caller: Principal) {
    if (Itertools.find(owners.vals(), func (cur: Principal): Bool { caller == cur }) == null) {
      Debug.trap("not an owner");
    };
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

  private func _getAttribute(sk: Text, subkey: Text): ?Entity.AttributeValue { 
    do ? { RBT.get<Text, Entity.AttributeValue>(CanDB.get(db, {sk})!.attributes, Text.compare, subkey)! };
  };

  public query func getAttribute(sk: Text, subkey: Text): async ?Entity.AttributeValue { 
    _getAttribute(sk, subkey);
  };

  public shared({caller}) func put(sk: Text, attributes: [(Entity.AttributeKey, Entity.AttributeValue)]): async () {
    onlyOwner(caller);
    await* CanDB.put(db, {sk; attributes});
  };

  private func _putAttribute(sk: Text, subkey: Entity.AttributeKey, attribute: Entity.AttributeValue) {
    ignore CanDB.update(db, { sk; updateAttributeMapFunction = func(old: ?Entity.AttributeMap): Entity.AttributeMap {
      let map = switch (old) {
        case (?old) { old };
        case null { RBT.init() };
      };
      RBT.put(map, Text.compare, subkey, attribute);
    }});
  };

  public shared({caller}) func putAttribute(sk: Text, subkey: Entity.AttributeKey, attribute: Entity.AttributeValue): async () {
    onlyOwner(caller);
    _putAttribute(sk, subkey, attribute);
  };

  // Repository data methods //

  private func _getFullPackageInfo(name: Common.PackageName): Common.SharedFullPackageInfo {
    switch (_getAttribute(name, "v")) { // version
      case (?#int 0) {
        switch (_getAttribute(name, "p")) {
          case (?#blob blob) {
            let ?result = from_candid(blob): ?Common.SharedFullPackageInfo else {
              Debug.trap("_getFullPackageInfo 1: programming error");
            };
            result;
          };
          case _ { Debug.trap("_getFullPackageInfo 2: programming error"); }
        }
      };
      case null { Debug.trap("no such package"); };
      case _ {
        Debug.trap("unsupported data version");
      };
    };
  };

  public query func getFullPackageInfo(name: Common.PackageName): async Common.SharedFullPackageInfo {
    _getFullPackageInfo(name);
  };

  private func _setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo) {
    let b = to_candid(info);
    _putAttribute(name, "v", #int 0); // version info
    _putAttribute(name, "p", #blob b);
  };

  /// TODO: Put a barrier to make the update atomic.
  /// TODO: Don't call it directly.
  public shared({caller}) func setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
    onlyOwner(caller);
    _setFullPackageInfo(name, info);
  };

  public query func getPackage(name: Common.PackageName, version: Common.Version): async Common.SharedPackageInfo {
    let fullInfo = _getFullPackageInfo(name);
    for ((curVersion, info) in fullInfo.packages.vals()) {
      if (curVersion == version) {
        return info;
      };
    };
    Debug.trap("no such package version");
  };

  // query func packagesByFunction(function: Common.PackageName): async [(Common.PackageName, Common.Version)] {
  // };
}