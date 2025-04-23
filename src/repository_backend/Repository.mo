import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import TrieMap "mo:base/TrieMap";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Sha256 "mo:sha2/Sha256";
import Common "../common";

shared ({caller = initialOwner}) actor class Repository() = this {
  stable var _ownersSave: [(Principal, ())] = [];
  var owners = HashMap.fromIter<Principal, ()>([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);
  stable var _packageCreatorsSave: [(Principal, ())] = [];
  var packageCreators = HashMap.fromIter<Principal, ()>([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

  stable var initialized: Bool = false;

  private func onlyOwner(caller: Principal) {
    if (Option.isNull(owners.get(caller))) {
      Debug.trap("not an owner");
    }
  };

  private func onlyPackageCreator(caller: Principal) {
    if (Option.isNull(owners.get(caller)) and Option.isNull(packageCreators.get(caller))) {
      Debug.trap("not an owner");
    }
  };

  private func onlyPackageOwner(caller: Principal, name: Text) {
    if (Option.isSome(owners.get(caller))) {
      return;
    };
    if (Option.isSome(do ? { packages.get(name)!.owners.get(caller) })) {
      return;
    };
    Debug.trap("not an owner");
  };

  public query func getOwners(): async [Principal] {
    Iter.toArray(owners.keys());
  };

  public query func getPackageCreators(): async [Principal] {
    Iter.toArray(packageCreators.keys());
  };

  public shared({caller}) func setOwners(newOwners: [Principal]): async () {
    onlyOwner(caller);
    owners := HashMap.fromIter(
      Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (x: Principal) = (x, ())),
      newOwners.size(),
      Principal.equal,
      Principal.hash);
  };

  public shared({caller}) func setPackageCreators(newOwners: [Principal]): async () {
    onlyOwner(caller);
    packageCreators := HashMap.fromIter(
      Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (x: Principal) = (x, ())),
      newOwners.size(),
      Principal.equal,
      Principal.hash);
  };

  public shared({caller}) func addOwner(newOwner: Principal): async () {
    onlyOwner(caller);
    owners.put(newOwner, ());
  };

  public shared({caller}) func addPackageCreator(newCreator: Principal): async () {
    onlyOwner(caller);
    packageCreators.put(newCreator, ());
  };

  public shared({caller}) func deleteOwner(oldOwner: Principal): async () {
    onlyOwner(caller);
    owners.delete(oldOwner);
  };

  public shared({caller}) func deletePackageCreator(oldPackageCreator: Principal): async () {
    onlyOwner(caller);
    packageCreators.delete(oldPackageCreator);
  };

  // TODO@P3: not needed
  public shared({caller}) func init(): async () {
    onlyOwner(caller);
    
    if (initialized) {
      Debug.trap("already initialized");
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
    onlyOwner(caller);
    repositoryName := value;
  };

  public shared({caller}) func setRepositoryInfoURL(value: Text): async () {
    onlyOwner(caller);
    repositoryInfoURL := value;
  };

  public shared({caller}) func setReleases(value: [(Text, ?Text)]): async () {
    onlyOwner(caller);
    releases := value;
  };

  private func _uploadWasm(wasm: Blob): async* {id: Blob} {
    let id0 = Sha256.fromBlob(#sha256, wasm);
    let id = Blob.fromArray(Array.subArray(Blob.toArray(id0), 0, 16));

    wasms.put(id, wasm);

    {id};
  };

  public shared({caller}) func uploadWasm(wasm: Blob): async {id: Blob} {
    onlyPackageCreator(caller);
  
    await* _uploadWasm(wasm);
  };

  public shared({caller}) func uploadModule(module_: Common.ModuleUpload): async Common.SharedModule {
    onlyPackageCreator(caller);

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
    onlyOwner(caller);

    defaultVersions := {versions; defaultVersionIndex};
  };

  public query func getDefaultVersions(): async RepositoryVersions {
    defaultVersions;
  };

  /// Data ///

  let wasms = TrieMap.TrieMap<Blob, Blob>(Blob.equal, Blob.hash);

  public query func getWasmModule(key: Blob): async Blob { 
    let ?v = wasms.get(key) else {
      Debug.trap("no such module");
    };
    v;
  };

  // TODO@P3: `removeWasmModule`

  let packages = TrieMap.TrieMap<Text, {
    pkg: Common.FullPackageInfo;
    owners: HashMap.HashMap<Principal, ()>;
  }>(Text.equal, Text.hash);

  private func _getFullPackageInfo(name: Common.PackageName): Common.SharedFullPackageInfo {
    let ?v = packages.get(name) else {
      Debug.trap("no such package");
    };
    Common.shareFullPackageInfo(v.pkg);
  };

  public query func getFullPackageInfo(name: Common.PackageName): async Common.SharedFullPackageInfo {
    _getFullPackageInfo(name);
  };

  /// TODO@P3: Put a barrier to make the update atomic.
  /// TODO@P3: Don't call it directly.
  public shared({caller}) func setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
    let p = packages.get(name);
    switch (p) {
      case (?p) {
        onlyPackageOwner(caller, name); // TODO@P3: queries by name second time.
      };
      case null {
        onlyPackageCreator(caller);
      };
    };

    // TODO@P3: Check that package exists?
    let owners = switch (p) {
      case (?{pkg = _; owners}) {
        owners;
      };
      case null {
        HashMap.fromIter<Principal, ()>(
          [(caller, ())].vals(),
          1,
          Principal.equal,
          Principal.hash);
      };
    };
    packages.put(name, {owners; pkg = Common.unshareFullPackageInfo(info)});
  };

  public query func getPackage(name: Common.PackageName, version: Common.Version): async Common.SharedPackageInfo {
    let ?fullInfo = packages.get(name) else {
      Debug.trap("no such package");
    };
    for ((curVersion, info) in fullInfo.pkg.packages.entries()) {
      if (curVersion == version or fullInfo.pkg.versionsMap.get(version) == ?curVersion) {
        return Common.sharePackageInfo(info);
      };
    };
    Debug.trap("no such package version");
  };

    system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());
        _packageCreatorsSave := Iter.toArray(packageCreators.entries());
    };

    system func postupgrade() {
        owners := HashMap.fromIter(
            _ownersSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _ownersSave := []; // Free memory.

        packageCreators := HashMap.fromIter(
            _packageCreatorsSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _packageCreatorsSave := []; // Free memory.
    };
}