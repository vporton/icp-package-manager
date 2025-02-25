/// TODO: Rename this file.
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import TrieMap "mo:base/TrieMap";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Common "../common";

shared ({caller = initialOwner}) actor class Repository() = this {
  var owners = HashMap.fromIter<Principal, ()>([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);
  
  var nextWasmId = 0;
  // var nextPackageId = 0; // TODO: unused

  // CanDB index methods //

  stable var initialized: Bool = false;

  private func onlyOwner(caller: Principal) {
    if (Option.isNull(owners.get(caller))) {
      Debug.trap("not an owner");
    }
  };

  public query func getOwners(): async [Principal] {
    Iter.toArray(owners.keys());
  };

  public shared({caller}) func setOwners(newOwners: [Principal]): async () {
    onlyOwner(caller);
    owners := HashMap.fromIter(
      Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (x: Principal) = (x, ())),
      newOwners.size(),
      Principal.equal,
      Principal.hash);
  };

  public shared({caller}) func addOwner(newOwner: Principal): async () {
    onlyOwner(caller);
    owners.put(newOwner, ());
  };

  public shared({caller}) func deleteOwner(newOwner: Principal): async () {
    onlyOwner(caller);
    owners.delete(newOwner);
  };

  // TODO: not needed
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

  private func _uploadWasm(wasm: Blob): async* {id: Nat} {
    let id = nextWasmId;
    nextWasmId += 1;

    wasms.put(id, wasm);

    {id};
  };

  public shared({caller}) func uploadWasm(wasm: Blob): async {id: Nat} {
    onlyOwner(caller);
  
    await* _uploadWasm(wasm);
  };

  public shared({caller}) func uploadModule(module_: Common.ModuleUpload): async Common.SharedModule {
    onlyOwner(caller);

    {
      callbacks = module_.callbacks;
      installByDefault = module_.installByDefault;
      forceReinstall = module_.forceReinstall;
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

  // TODO: Use hashes instead of numbers, for balanced tree and duplicate elimination.
  let wasms = TrieMap.TrieMap<Nat, Blob>(Nat.equal, Common.IntHash);

  public query func getWasmModule(key: Nat): async Blob { 
    let ?v = wasms.get(key) else {
      Debug.trap("no such module");
    };
    v;
  };

  // TODO: `removeWasmModule`

  let packages = TrieMap.TrieMap<Text, Common.FullPackageInfo>(Text.equal, Text.hash);

  private func _getFullPackageInfo(name: Common.PackageName): Common.SharedFullPackageInfo {
    let ?v = packages.get(name) else {
      Debug.trap("no such package");
    };
    Common.shareFullPackageInfo(v);
  };

  public query func getFullPackageInfo(name: Common.PackageName): async Common.SharedFullPackageInfo {
    _getFullPackageInfo(name);
  };

  /// TODO: Put a barrier to make the update atomic.
  /// TODO: Don't call it directly.
  public shared({caller}) func setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
    onlyOwner(caller);

    // TODO: Check that package exists?
    packages.put(name, Common.unshareFullPackageInfo(info));
  };

  public shared({caller}) func createPackage(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
    onlyOwner(caller);

    if (Option.isSome(packages.get(name))) {
      Debug.trap("package already exists");
    };
    packages.put(name, Common.unshareFullPackageInfo(info));
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

  // public shared({caller}) func uploadModules(modules: [(Text, Common.ModuleUpload)]): async [(Text, Common.Module)] {
  //   onlyOwner(caller);
  //   let buf = Buffer.Buffer<(Text, Common.Module)>(Array.size(modules));
  //   for (m in modules.vals()) {
  //     buf.add(m.0, await* uploadModule(m.1));
  //   };
  //   Buffer.toArray(buf);
  // };

  // TODO: Remove?
  // TODO: two shared calls here
  // public shared({caller}) func uploadRealPackageInfo(info: Common.RealPackageInfoUpload): async Common.RealPackageInfo {
  //   onlyOwner(caller);
  //   {
  //     modules = await uploadModules(info.modules);
  //     extraModules = await uploadModules(info.extraModules);
  //     dependencies = info.dependencies;
  //     functions = info.functions;
  //     permissions = info.permissions;
  //   };
  // };
}