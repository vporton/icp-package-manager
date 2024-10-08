import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import StableBuffer "mo:stablebuffer/StableBuffer";
import Admin "mo:candb/CanDBAdmin";
import CA "mo:candb/CanisterActions";
import CanisterMap "mo:candb/CanisterMap";
import RepositoryPartition "RepositoryPartition";
import Utils "mo:candb/Utils";
import Base32 "mo:encoding.mo/Base32";
import Common "../common";

shared ({caller = initialOwner}) actor class RepositoryIndex() = this {
  var owner = initialOwner;
  
  var nextWasmId = 0;
  var nextPackageId = 0; // TODO: unused

  // CanDB index methods //

  let maxSize = #heapSize(500_000_000);

  stable var pkToCanisterMap = CanisterMap.init();

  stable var initialized: Bool = false;

  private func onlyOwner(caller: Principal) {
    if (caller != owner) {
      Debug.trap("not an owner");
    }
  };

  public query func getOwner(): async Principal {
    owner;
  };

  public shared({caller}) func setOwner(newOwner: Principal): async () {
    onlyOwner(caller);
    owner := newOwner;
  };

  public shared({caller}) func init(): async () {
    ignore Cycles.accept<system>(300_000_000_000_000); // FIXME
    onlyOwner(caller);
    
    if (initialized) {
      Debug.trap("already initialized");
    };

    // TODO: Need to be a self-controller?
    ignore await* createStorageCanister("main", [owner]);
    ignore await* createStorageCanister("wasms", [owner]);

    initialized := true;
  };

  /// @required API (Do not delete or change)
  ///
  /// Get all canisters for an specific PK
  public shared query func getCanistersByPK(pk: Text): async [Text] {
    getCanisterIdsIfExists(pk);
  };
  
  private func getLastCanisterByPKInternal(pk: Text): Text {
    let all = getCanisterIdsIfExists(pk);
    all[Array.size(all) - 1];
  };
  
  public shared query func getLastCanisterByPK(pk: Text): async Text {
    getLastCanisterByPKInternal(pk);
  };
  
  /// Helper function that creates a user canister for a given PK
  func createUserCanister(pk: Text, controllers: ?[Principal]): async Text {
    Debug.print("creating new user canister with pk=" # pk);
    Cycles.add<system>(100_000_000_000_000); // FIXME
    let newUserCanister = await RepositoryPartition.RepositoryPartition({
      partitionKey = pk;
      scalingOptions = {
        autoScalingHook = autoScaleUserCanister;
        sizeLimit = maxSize;
      };
      owners = [owner, Principal.fromActor(this)]; // FIXME
    });
    let newUserCanisterPrincipal = Principal.fromActor(newUserCanister);
    await CA.updateCanisterSettings({
      canisterId = newUserCanisterPrincipal;
      settings = {
        controllers = controllers;
        compute_allocation = ?0;
        memory_allocation = ?0;
        freezing_threshold = ?2592000; // TODO
      };
    });

    let newUserCanisterId = Principal.toText(newUserCanisterPrincipal);
    pkToCanisterMap := CanisterMap.add(pkToCanisterMap, pk, newUserCanisterId);

    newUserCanisterId;
  };

  /// This hook is called by CanDB for AutoScaling the User Service Actor.
  ///
  /// If the developer does not spin up an additional User canister in the same partition within this method, auto-scaling will NOT work
  public shared ({caller = caller}) func autoScaleUserCanister(pk: Text): async Text {
    // Auto-Scaling Authorization - ensure the request to auto-scale the partition is coming from an existing canister in the partition, otherwise reject it
    if (Utils.callingCanisterOwnsPK(caller, pkToCanisterMap, pk)) {
      await createUserCanister(pk, ?[owner, Principal.fromActor(this)]); // TODO: need to be our own owner?
    } else {
      Debug.trap("error, called by non-controller=" # debug_show(caller));
    };
  };
  
  /// @required function (Do not delete or change)
  ///
  /// Helper method acting as an interface for returning an empty array if no canisters
  /// exist for the given PK
  func getCanisterIdsIfExists(pk: Text): [Text] {
    switch(CanisterMap.get(pkToCanisterMap, pk)) {
      case null { [] };
      case (?canisterIdsBuffer) { StableBuffer.toArray(canisterIdsBuffer) } 
    }
  };

  /// Upgrade user canisters in a PK range, i.e. rolling upgrades (limit is fixed at upgrading the canisters of 5 PKs per call)
  public shared({ caller = caller }) func upgradeUserCanistersInPKRange(wasmModule: Blob): async Admin.UpgradePKRangeResult {
    if (caller != owner) { // basic authorization
      return {
        upgradeCanisterResults = [];
        nextKey = null;
      }
    }; 

    await Admin.upgradeCanistersInPKRange({
      canisterMap = pkToCanisterMap;
      lowerPK = "";
      upperPK = "z";
      limit = 5;
      wasmModule = wasmModule;
      scalingOptions = {
        autoScalingHook = autoScaleUserCanister;
        sizeLimit = #count(20)
      };
      owners = ?[owner, Principal.fromActor(this)]; // TODO: need to be our own owner?
    });
  };

  public shared({caller}) func autoScaleCanister(pk: Text): async Text {
    onlyOwner(caller);

    if (Utils.callingCanisterOwnsPK(caller, pkToCanisterMap, pk)) {
      await* createStorageCanister(pk, [owner]); // FIXME: Should include self?
    } else {
      Debug.trap("error, called by non-controller=" # debug_show(caller));
    };
  };

  func createStorageCanister(pk: Text, controllers: [Principal]): async* Text {
    Debug.print("creating new storage canister with pk=" # pk);
    // Pre-load 300 billion cycles for the creation of a new storage canister
    // Note that canister creation costs 100 billion cycles, meaning there are 200 billion
    // left over for the new canister when it is created
    Cycles.add<system>(100_000_000_000_000);
    let newStorageCanister = await RepositoryPartition.RepositoryPartition({
      partitionKey = pk;
      scalingOptions = {
        autoScalingHook = autoScaleCanister;
        sizeLimit = maxSize;
      };
      owners = [Principal.fromActor(this), owner]; // FIXME: Do we need `owner` here?
    });
    let newStorageCanisterPrincipal = Principal.fromActor(newStorageCanister);
    // Battery.addRepositoryPartition(newStorageCanisterPrincipal); // FIXME
    await CA.updateCanisterSettings({
      canisterId = newStorageCanisterPrincipal;
      settings = {
        controllers = ?controllers;
        compute_allocation = ?0;
        memory_allocation = ?0;
        freezing_threshold = ?2592000;
      }
    });

    let newStorageCanisterId = Principal.toText(newStorageCanisterPrincipal);
    pkToCanisterMap := CanisterMap.add(pkToCanisterMap, pk, newStorageCanisterId);

    Debug.print("new storage canisterId=" # newStorageCanisterId);
    newStorageCanisterId;
  };

  // Repository index methods //

  /// Something like "Mandrake ICP".
  stable var repositoryName: Text = "";

  stable var repositoryInfoURL: Text = "";

  stable var releases: [(Text, ?Text)] = [];

  public query func getRepositoryPartitions(): async [Principal] {
    Iter.toArray(Iter.map(
      getCanisterIdsIfExists("main").vals(),
      func (t: Text): Principal = Principal.fromText(t),
    ));
  };

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

  // Not exactly very efficient, but optimizing this is hard.
  private func encodeId(id: Nat): Text {
    let idAsBytes = Buffer.Buffer<Nat8>(0); // TODO: mo:base.StableBuffer vs mo:stablebuffer
    var idBuf = id;
    while (idBuf != 0) {
      idAsBytes.add(Nat8.fromNat(idBuf % 256));
      idBuf /= 256;
    };
    let idEncoded = Base32.encode(Buffer.toArray(idAsBytes));
    let ?text = Text.decodeUtf8(Blob.fromArray(idEncoded)) else {
      Debug.trap("programming error");
    };
    text;
  };

  public shared({caller}) func uploadWasm(wasm: Blob): async {canister: Principal; id: Text} {
    onlyOwner(caller);
    let id = nextWasmId;
    nextWasmId += 1;
    let idText = encodeId(id);

    let part0 = getLastCanisterByPKInternal("wasms");
    let part: RepositoryPartition.RepositoryPartition = actor(part0);
    await part.putAttribute(idText, "w", #blob wasm);

    {canister = Principal.fromActor(part); id = idText};
  };

  public shared({caller}) func createPackage(name: Common.PackageName, info: Common.FullPackageInfo): async {canister: Principal} {
    onlyOwner(caller);
    let part0 = getLastCanisterByPKInternal("main");
    let part: RepositoryPartition.RepositoryPartition = actor(part0);
    await part.setFullPackageInfo(name, info); // FIXME: Prevent duplicates.
    {canister = Principal.fromActor(part)};
  };
}