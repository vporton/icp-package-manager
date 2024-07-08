import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import CA "mo:candb/CanisterActions";
import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import RBT "mo:stable-rbtree/StableRBTree";
import Itertools "mo:itertools/Iter";
import Common "common";

shared ({ caller = owner }) actor class RepositoryPartition({
  partitionKey: Text;
  scalingOptions: CanDB.ScalingOptions;
  owners: [Principal]
}) {
  // CanDB paritition methods //

  private func onlyOwner(caller: Principal) {
    if (Itertools.find(owners.vals(), func (cur: Principal): Bool { caller == cur }) == null) {
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

  // Repository data methods //

  type FullPackageInfo = {
    packages: [(Common.Version, Common.PackageInfo)];
    versionsMap: [(Common.Version, Common.Version)];
  };

  /// TODO: used for testing, remove
  stable var test: ?FullPackageInfo = null;

  // query func getPackageVersions(name: Text): async [(Version, ?Version)] {
  //   // TODO: Need to store all versions of a package in a single object for efficient enumeration.
  // };

  // query func getPackageVersionsMap(name: Text): async [(Version, Version)] {
  // };

  // query func getPackage(name: Text, version: Version): async PackageInfo {

  // };

  // query func packagesByFunction(function: Text): async [(Common.PackageName, Common.Version)] {

  // };
}