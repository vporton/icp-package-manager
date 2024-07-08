import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
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
}) = this {
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

  private func _getFullPackageInfo(name: Common.PackageName): FullPackageInfo {
    let ?data = _getAttribute(name, "p") else {
      Debug.trap("no such package");
    };
    let #tuple data2 = data else {
      Debug.trap("programming error");
    };
    if (data2[0] != #int 0) {
      Debug.trap("unsupported data version");
    };
    if (Array.size(data2) != 2) {
      Debug.trap("programming error");
    };
    let #blob data3 = data2[1] else {
      Debug.trap("programming error");
    };
    let ?data4 = from_candid(data3): ?FullPackageInfo else {
      Debug.trap("programming error");
    };
    data4;
  };

  public composite query func getFullPackageInfo(name: Common.PackageName): async FullPackageInfo {
    _getFullPackageInfo(name);
  };

  // query func getPackageVersions(name: Common.PackageName): async [Common.Version] {
  //   // TODO: Need to store all versions of a package in a single object for efficient enumeration.
  // };

  // query func getPackageVersionsMap(name: Common.PackageName): async [(Common.Version, Common.Version)] {
  // };

  public query func getPackage(name: Common.PackageName, version: Common.Version): async Common.PackageInfo {
    let fullInfo = _getFullPackageInfo(name);
    for ((curVersion, info) in fullInfo.packages.vals()) {
      if (curVersion == version) {
        return info;
      };
    };
    Debug.trap("no such package");
  };

  // query func packagesByFunction(function: Text): async [(Common.PackageName, Common.Version)] {

  // };
}