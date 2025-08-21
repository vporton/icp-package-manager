import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Option "mo:core/Option";
import Result "mo:core/Result";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Error "mo:core/Error";
import Sha256 "mo:sha2/Sha256";
import Common "../common";

// FIXME@P1: Need to make it persistent.
shared ({caller = initialOwner}) persistent actor class Repository() = this {
  var owners = Map.fromIter<Principal, ()>([(initialOwner, ())].vals(), Principal.compare); // FIXME@P1: Use `Set` instead of `Map`.
  var packageCreators = Map.fromIter<Principal, ()>([(initialOwner, ())].vals(), Principal.compare); // FIXME@P1: Use `Set` instead of `Map`.

  stable var initialized: Bool = false;

  private func onlyOwner(caller: Principal): async* () {
    if (Option.isNull(Map.get(owners, Principal.compare, caller))) {
      throw Error.reject("not an owner");
    }
  };

  private func onlyPackageCreator(caller: Principal): async* () {
    if (Option.isNull(Map.get(owners, Principal.compare, caller)) and Option.isNull(Map.get(packageCreators, Principal.compare, caller))) {
      throw Error.reject("not an owner");
    }
  };

  private func onlyPackageOwner(caller: Principal, name: Text): Result.Result<(), Text> {
    if (Option.isSome(Map.get(owners, Principal.compare, caller))) {
      return #ok;
    };
    if (Option.isSome(do ? { Map.get(Map.get(packages, Text.compare, name)!.owners, Principal.compare, caller) })) {
      return #ok;
    };
    #err("not an owner");
  };

  public query func getOwners(): async [Principal] {
    Iter.toArray(Map.keys(owners));
  };

  public query func getPackageCreators(): async [Principal] {
    Iter.toArray(Map.keys(packageCreators));
  };

  public shared({caller}) func setOwners(newOwners: [Principal]): async () {
    await* onlyOwner(caller);
    owners := Map.fromIter(
      Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (x: Principal) = (x, ())),
      Principal.compare);
  };

  public shared({caller}) func setPackageCreators(newOwners: [Principal]): async () {
    await* onlyOwner(caller);
    packageCreators := Map.fromIter(
      Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (x: Principal) = (x, ())),
      Principal.compare);
  };

  public shared({caller}) func addOwner(newOwner: Principal): async () {
    await* onlyOwner(caller);
    ignore Map.insert(owners, Principal.compare, newOwner, ());
  };

  public shared({caller}) func addPackageCreator(newCreator: Principal): async () {
    await* onlyOwner(caller);
    ignore Map.insert(packageCreators, Principal.compare, newCreator, ());
  };

  public shared({caller}) func deleteOwner(oldOwner: Principal): async () {
    await* onlyOwner(caller);
    ignore Map.delete<Principal, ()>(owners, Principal.compare, oldOwner); // FIXME@P1: Use `Set` instead of `Map`.
  };

  public shared({caller}) func deletePackageCreator(oldPackageCreator: Principal): async () {
    await* onlyOwner(caller);
    ignore Map.delete<Principal, ()>(packageCreators, Principal.compare, oldPackageCreator); // FIXME@P1: Use `Set` instead of `Map`.
  };

  // TODO@P3: not needed
  public shared({caller}) func init(): async () {
    await* onlyOwner(caller);
    
    if (initialized) {
      throw Error.reject("already initialized");
    };

    initialized := true;
  };

  // Repository index methods //

  /// Something like "Mandrake ICP".
  stable var repositoryName: Text = "";

  stable var repositoryInfoURL: Text = "";

  stable var releases: [(Text, ?Text)] = [];

  public query func getRepositoryName(): async Text {
    repositoryName;
  };

  public query func getRepositoryInfoURL(): async Text {
    repositoryInfoURL;
  };

  public query func getReleases(): async [(Text, ?Text)] {
    releases;
  };

  public shared({caller}) func setRepositoryName(value: Text): async () {
    await* onlyOwner(caller);
    repositoryName := value;
  };

  public shared({caller}) func setRepositoryInfoURL(value: Text): async () {
    await* onlyOwner(caller);
    repositoryInfoURL := value;
  };

  public shared({caller}) func setReleases(value: [(Text, ?Text)]): async () {
    await* onlyOwner(caller);
    releases := value;
  };

  private func _uploadWasm(wasm: Blob): async* {id: Blob} {
    let id0 = Sha256.fromBlob(#sha256, wasm);
    let id = Blob.fromArray(Array.sliceToArray(Blob.toArray(id0), 0, 16));

    ignore Map.insert(wasms, Blob.compare, id, wasm);

    {id};
  };

  public shared({caller}) func uploadWasm(wasm: Blob): async {id: Blob} {
    await* onlyPackageCreator(caller);
  
    await* _uploadWasm(wasm);
  };

  public shared({caller}) func uploadModule(module_: Common.ModuleUpload): async Common.SharedModule {
    await* onlyPackageCreator(caller);

    {
      callbacks = module_.callbacks;
      installByDefault = module_.installByDefault;
      forceReinstall = module_.forceReinstall;
      canisterVersion = module_.canisterVersion;
      code = switch (module_.code) {
        case (#Wasm blob) {
            let {id} = await* _uploadWasm(blob);
            #Wasm (Principal.fromActor(this), id);
        };
        case (#Assets {wasm: Blob; assets: Principal}) {
          let {id} = await* _uploadWasm(wasm);
          #Assets {wasm = (Principal.fromActor(this), id); assets};
        };
      };
    };
  };

  type RepositoryVersions = {
    versions: [Common.Version];
    defaultVersionIndex: Nat;
  };
  stable var defaultVersions: RepositoryVersions = {versions = []; defaultVersionIndex = 0};

  public shared({caller}) func setDefaultVersions({
    versions: [Common.Version];
    defaultVersionIndex: Nat;
  }) {
    await* onlyOwner(caller);

    defaultVersions := {versions; defaultVersionIndex};
  };

  public query func getDefaultVersions(): async RepositoryVersions {
    defaultVersions;
  };

  /// Data ///

  let wasms = Map.empty<Blob, Blob>();

  public query func getWasmModule(key: Blob): async Blob { 
    let ?v = Map.get(wasms, Blob.compare, key) else {
      throw Error.reject("no such module");
    };
    v;
  };

  // TODO@P3: `removeWasmModule`

  let packages = Map.empty<Text, {
    pkg: Common.FullPackageInfo;
    owners: Map.Map<Principal, ()>;
  }>();

  private func _getFullPackageInfo(name: Common.PackageName): Result.Result<Common.SharedFullPackageInfo, Text> {
    let ?v = Map.get(packages, Text.compare, name) else {
      return #err("no such package");
    };
    #ok(Common.shareFullPackageInfo(v.pkg));
  };

  public query func getFullPackageInfo(name: Common.PackageName): async Common.SharedFullPackageInfo {
    switch (_getFullPackageInfo(name)) {
      case (#ok v) v;
      case (#err e) throw Error.reject(e);
    };
  };

  /// TODO@P3: Put a barrier to make the update atomic.
  /// TODO@P3: Don't call it directly.
  public shared({caller}) func setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
    let p = Map.get(packages, Text.compare, name);
    switch (p) {
      case (?p) {
        switch (onlyPackageOwner(caller, name)) { // TODO@P3: queries by name second time.
          case (#ok) {};
          case (#err e) throw Error.reject(e);
        };
      };
      case null {
        await* onlyPackageCreator(caller);
      };
    };

    // TODO@P3: Check that package exists?
    let owners = switch (p) {
      case (?{pkg = _; owners}) {
        owners;
      };
      case null {
        Map.fromIter<Principal, ()>(
          [(caller, ())].vals(),
          Principal.compare);
      };
    };
    ignore Map.insert(packages, Text.compare, name, {owners; pkg = Common.unshareFullPackageInfo(info)});
  };

  public query func getPackage(name: Common.PackageName, version: Common.Version): async Common.SharedPackageInfo {
    let ?fullInfo = Map.get(packages, Text.compare, name) else {
      throw Error.reject("no such package");
    };
    for ((curVersion, info) in Map.entries(fullInfo.pkg.packages)) {
      if (curVersion == version or Map.get(fullInfo.pkg.versionsMap, Text.compare, version) == ?curVersion) {
        return Common.sharePackageInfo(info);
      };
    };
    throw Error.reject("no such package version");
  };

  public shared({caller}) func cleanUnusedWasms() {
    await* onlyOwner(caller);

    let usedWasms = Map.empty<Blob, ()>();
    for (pkg in Map.values(packages)) {
      for (info in Map.values(pkg.pkg.packages)) {
        switch (info.specific) {
          case (#real p) {
            for ({code} in Map.values(p.modules)) {
              let id = switch (code) {
                case (#Wasm wasm) wasm;
                case (#Assets {wasm}) wasm;
              };
              ignore Map.insert(usedWasms, Blob.compare, id.1, ());
            };
          };
          case (#virtual _) {};
        };
      };
    };

    for (wasm in Map.keys(wasms)) {
      if (Option.isNull(Map.get(usedWasms, Blob.compare, wasm))) {
        ignore Map.delete<Blob, Blob>(wasms, Blob.compare, wasm);
      };
    };
  };
}