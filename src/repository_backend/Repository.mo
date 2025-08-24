import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import List "mo:core/List";
import Map "mo:core/Map";
import Set "mo:core/Set";
import Nat "mo:core/Nat";
import Option "mo:core/Option";
import Result "mo:core/Result";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Error "mo:core/Error";
import Runtime "mo:core/Runtime";
import Sha256 "mo:sha2/Sha256";
import Common "../common";

shared ({caller = initialOwner}) persistent actor class Repository() = this {
  var owners = Set.fromIter<Principal>([initialOwner].vals(), Principal.compare);
  var packageCreators = Set.fromIter<Principal>([initialOwner].vals(), Principal.compare);

  stable var initialized: Bool = false;

  private func onlyOwner(caller: Principal): async* () {
    if (not Set.contains(owners, Principal.compare, caller)) {
      throw Error.reject("not an owner");
    }
  };

  private func onlyPackageCreator(caller: Principal): async* () {
    if (not Set.contains(owners, Principal.compare, caller) and not Set.contains(packageCreators, Principal.compare, caller)) {
      throw Error.reject("not an owner");
    }
  };

  private func onlyPackageOwner(caller: Principal, name: Text): Result.Result<(), Text> {
    if (Set.contains(owners, Principal.compare, caller)) {
      return #ok;
    };
    if ((do ? { Set.contains<Principal>(Map.get(packages, Text.compare, name)!.owners, Principal.compare, caller) }) == ?true) {
      return #ok;
    };
    #err("not an owner");
  };

  public query func getOwners(): async [Principal] {
    Iter.toArray(Set.values(owners));
  };

  public query func getPackageCreators(): async [Principal] {
    Iter.toArray(Set.values(packageCreators));
  };

  public shared({caller}) func setOwners(newOwners: [Principal]): async () {
    await* onlyOwner(caller);
    owners := Set.fromIter<Principal>(newOwners.vals(), Principal.compare);
  };

  public shared({caller}) func setPackageCreators(newOwners: [Principal]): async () {
    await* onlyOwner(caller);
    packageCreators := Set.fromIter<Principal>(newOwners.vals(), Principal.compare);
  };

  public shared({caller}) func addOwner(newOwner: Principal): async () {
    await* onlyOwner(caller);
    ignore Set.insert<Principal>(owners, Principal.compare, newOwner);
  };

  public shared({caller}) func addPackageCreator(newCreator: Principal): async () {
    await* onlyOwner(caller);
    ignore Set.insert<Principal>(packageCreators, Principal.compare, newCreator);
  };

  public shared({caller}) func deleteOwner(oldOwner: Principal): async () {
    await* onlyOwner(caller);
    ignore Set.delete<Principal>(owners, Principal.compare, oldOwner);
  };

  public shared({caller}) func deletePackageCreator(oldPackageCreator: Principal): async () {
    await* onlyOwner(caller);
    ignore Set.delete<Principal>(packageCreators, Principal.compare, oldPackageCreator);
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
    owners: Set.Set<Principal>;
  }>();

  // private func _getFullPackageInfo(name: Common.PackageName): Result.Result<Common.SharedFullPackageInfo, Text> {
  //   let ?v = Map.get(packages, Text.compare, name) else {
  //     return #err("no such package");
  //   };
  //   #ok(Common.shareFullPackageInfo(v.pkg));
  // };

  // TODO@P2: Uncomment.
  // public query func getFullPackageInfo(name: Common.PackageName): async Common.SharedFullPackageInfo {
  //   switch (_getFullPackageInfo(name)) {
  //     case (#ok v) v;
  //     case (#err e) throw Error.reject(e);
  //   };
  // };

  // TODO@P2: Shouldn't `tmpl` be stored in the backend, for consistency?
  public shared({caller}) func addPackageVersion(
    name: Common.PackageName,
    tmpl: Common.SharedPackageInfoTemplate,
    modules: [(Text, Common.SharedModule)],
  ): async () {
    let info = Common.fillPackageInfoTemplate(tmpl, modules);

    let p = Map.get(packages, Text.compare, name);
    switch (p) {
      case (?p) {
        switch (onlyPackageOwner(caller, name)) { // TODO@P3: queries by name second time.
          case (#ok) {};
          case (#err e) throw Error.reject(e);
        };

        let ?previous = List.last(p.pkg.packages) else {
          Runtime.unreachable(); // FIXME@P3: It may be reached due to `setFullPackageInfo()`.
        };
        if (Common.sharePackageInfo(info) != Common.sharePackageInfo(previous.package)) { // TODO@P3: inefficient
          List.add(p.pkg.packages, {serial = List.size(p.pkg.packages); package = info});
        };
      };
      case null {
        await* onlyPackageCreator(caller);

        let owners = switch (p) {
          case (?{pkg = _; owners}) {
            owners;
          };
          case null {
            Set.singleton<Principal>(caller);
          };
        };
        ignore Map.insert<Text, {
          pkg: Common.FullPackageInfo;
          owners: Set.Set<Principal>;
        }>(packages, Text.compare, name, {owners; pkg = {packages = List.singleton<Common.IndexedPackageInfo>({serial = 0; package = info}); versionsMap = Map.empty<Common.Version, Common.IndexedPackageInfo>()}});
      };
    };
  };

  /// TODO@P3: Put a barrier to make the update atomic.
  /// TODO@P3: Don't call it directly.
  // public shared({caller}) func setFullPackageInfo(name: Common.PackageName, info: Common.SharedFullPackageInfo): async () {
  //   let p = Map.get(packages, Text.compare, name);
  //   switch (p) {
  //     case (?p) {
  //       switch (onlyPackageOwner(caller, name)) { // TODO@P3: queries by name second time.
  //         case (#ok) {};
  //         case (#err e) throw Error.reject(e);
  //       };
  //     };
  //     case null {
  //       await* onlyPackageCreator(caller);
  //     };
  //   };

  //   // TODO@P3: Check that package exists?
  //   let owners = switch (p) {
  //     case (?{pkg = _; owners}) {
  //       owners;
  //     };
  //     case null {
  //       Set.singleton<Principal>(caller);
  //     };
  //   };
  //   ignore Map.insert(packages, Text.compare, name, {owners; pkg = Common.unshareFullPackageInfo(info)});
  // };

  public query func getPackage(name: Common.PackageName, version: Common.Version): async Common.SharedPackageInfo {
    let ?fullInfo = Map.get(packages, Text.compare, name) else {
      throw Error.reject("no such package");
    };
    let ?t = Map.get(fullInfo.pkg.versionsMap, Text.compare, version) else {
      throw Error.reject("no such package version");
    };
    Common.sharePackageInfo(t.package);
  };

  public shared({caller}) func cleanUnusedWasms() {
    await* onlyOwner(caller);

    let usedWasms = Map.empty<Blob, ()>();
    for (pkg in Map.values(packages)) {
      for (info in List.values(pkg.pkg.packages)) {
        switch (info.package.specific) {
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