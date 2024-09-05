import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";
import Asset "mo:assets-api";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import CopyAssets "../copy_assets";
import IndirectCaller "indirect_caller";
import Install "../install";

/// TODO: Methods to query for all installed packages.
shared({caller = initialOwner}) actor class PackageManager() = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

    // FIXME: UUID prefix to init and conform to API.
    // FIXME: Check function signature:
    public shared({caller}) func init({indirect_caller: IndirectCaller.IndirectCaller}) : async () {
        ignore Cycles.accept<system>(10_000_000_000_000); // FIXME
        onlyOwner(caller);

        indirect_caller_ := ?indirect_caller;
        let IC = actor ("aaaaa-aa") : actor {
            deposit_cycles : shared { canister_id : Common.canister_id } -> async ();
        };
        Cycles.add<system>(5_000_000_000_000); // FIXME
        await IC.deposit_cycles({ canister_id = Principal.fromActor(indirect_caller) });

        // TODO
        // let installationId = nextInstallationId;
        // nextInstallationId += 1;

        // let part: Common.RepositoryPartitionRO = actor (Principal.toText(packageCanister));
        // let package = await part.getPackage("package-manager", version);
        // let numPackages = Array.size(modules);
        // let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
        //     shouldHaveModules = numPackages;
        //     name = "package-manager";
        //     version = version;
        //     modules = Buffer.fromArray(modules); // Pretend that our package's modules are already installed.
        //     package;
        //     packageCanister;
        // };
        // halfInstalledPackages.put(installationId, ourHalfInstalled);

        // _updateAfterInstall({installationId});

        // TODO
        // owners := HashMap.fromIter([(user, ())].vals(), 1, Principal.equal, Principal.hash);
    };

    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller_2 = indirect_caller_ else {
            Debug.trap("indirect_caller_ not initialized");
        };
        indirect_caller_2;
    };

    stable var nextInstallationId: Nat = 0;

    stable var _installedPackagesSave: [(Common.InstallationId, Common.InstalledPackageInfo)] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Int.hash);

    stable var _installedPackagesByNameSave: [(Common.PackageName, [Common.InstallationId])] = [];
    var installedPackagesByName: HashMap.HashMap<Common.PackageName, [Common.InstallationId]> =
        HashMap.fromIter([].vals(), 0, Text.equal, Text.hash);

    stable var _halfInstalledPackagesSave: [(Common.InstallationId, {
        /// The number of modules in fully installed state.
        shouldHaveModules: Nat;
        name: Common.PackageName;
        version: Common.Version;
        modules: [Principal];
    })] = [];
    // TODO: `var` or `let` here and in other places:
    var halfInstalledPackages: HashMap.HashMap<Common.InstallationId, Common.HalfInstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Int.hash);

    stable var repositories: [{canister: Principal; name: Text}] = []; // TODO: a more suitable type like `HashMap` or at least `Buffer`?

    func onlyOwner(caller: Principal) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner");
        }
    };

    public shared({caller}) func installPackage({
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
    })
        : async {installationId: Common.InstallationId; canisterIds: [Principal]}
    {
        // onlyOwner(caller); // FIXME

        await* _installPackage({caller; canister; packageName; version; preinstalledModules = null});
    };

    public shared({caller}) func installPackageWithPreinstalledModules({
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: [Common.Location];
    })
        : async {installationId: Common.InstallationId; canisterIds: [Principal]}
    {
        // onlyOwner(caller); // FIXME

        await* _installPackage({caller; canister; packageName; version; preinstalledModules = ?preinstalledModules});
    };

    /// We don't install dependencies here (see `specs.odt`).
    private func _installPackage({
        caller: Principal;
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: ?[Common.Location];
    })
        : async* {installationId: Common.InstallationId; canisterIds: [Principal]}
    {
        let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
        // FIXME: Here an in other places, a hacker may make PM non-upgradeable.
        //        So, let we call IndirectCaller that first calls distro, then makes a call back to us to modify the data.
        let package = await part.getPackage(packageName, version);
        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        let numPackages = Array.size(realPackage.modules);

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = numPackages;
            // id = installationId;
            name = package.base.name;
            version = package.base.version;
            modules = Buffer.Buffer<Principal>(numPackages);
            // packageDescriptionIn = part;
            package;
            packageCanister = canister;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        let {canisterIds} = await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
            preinstalledModules;
        });

        {installationId; canisterIds};
    };

    /// Finish installation of a half-installed package.
    public shared({caller}) func finishInstallPackage({
        installationId: Nat;
    }): async {canisterIds: [Principal]} {
        onlyOwner(caller);
        
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        let #real realPackage = ourHalfInstalled.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
            preinstalledModules = null; // FIXME
        });
    };

    private func _finishInstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
        caller: Principal;
        preinstalledModules: ?[Common.Location];
    }): async* {canisterIds: [Principal]} {
        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        let canisterIds = Buffer.Buffer<Principal>(realPackage.modules.size());
        // TODO: Don't wait for creation of a previous canister to create the next one.
        for (i in Iter.range(0, realPackage.modules.size() - 1)) {
            let wasmModule = realPackage.modules[i];
            Cycles.add<system>(10_000_000_000_000); // FIXME
            let canister_id = switch (preinstalledModules) {
                case (?preinstalledModules) {
                    assert preinstalledModules.size() == realPackage.modules.size();
                    preinstalledModules[i].0;
                };
                case null {
                    let {canister_id} = await IC.create_canister({
                        settings = ?{
                            freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                            controllers = ?[Principal.fromActor(this), Principal.fromActor(getIndirectCaller())];
                            compute_allocation = null; // TODO
                            memory_allocation = null; // TODO (a low priority task)
                        }
                    });
                    canister_id;
                };
            };
            let wasmModuleLocation = switch (wasmModule) {
                case (#Wasm wasmModuleLocation) {
                    wasmModuleLocation;
                };
                case (#Assets {wasm}) {
                    wasm;
                };
            };
            let wasmModuleSourcePartition: RepositoryPartition.RepositoryPartition =
                actor(Principal.toText(wasmModuleLocation.0));
            let ?(#blob wasm_module) =
                await wasmModuleSourcePartition.getAttribute(wasmModuleLocation.1, "w")
            else {
                Debug.trap("package WASM code is not available");
            };
            let installArg = to_candid({
                user = caller;
                previousCanisters = Buffer.toArray(ourHalfInstalled.modules); // TODO: We can create all canisters first and pass all, not just previous.
                packageManager = this;
            });
            if (preinstalledModules == null) {
                // TODO: ignore?
                ignore await* Install._installModule(wasmModule, installArg, getIndirectCaller());
            }/* else {
                // We don't need to initialize installed module, because it can be only
                // PM's frontend.
            }*/;
            // TODO: Are two lines below duplicates of each other?
            canisterIds.add(canister_id); // do it later.
            ourHalfInstalled.modules.add(canister_id);
        };
        getIndirectCaller().callIgnoringMissing(
            Iter.toArray(Iter.map<Nat, {canister: Principal; name: Text; data: Blob}>(
                Buffer.toArray(ourHalfInstalled.modules).keys(), // TODO: inefficient?
                func (i: Nat) = {
                    canister = ourHalfInstalled.modules.get(i);
                    name = Common.NamespacePrefix # "init";
                    data = to_candid({
                        user = caller;
                        previousCanisters = Array.subArray<Principal>(Buffer.toArray(ourHalfInstalled.modules), 0, i);
                        packageManager = this;
                    });
                },
            )),
        );

        _updateAfterInstall({installationId});

        {canisterIds = Buffer.toArray(canisterIds)};
    };

    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        Debug.print("Add installationId: " # debug_show(installationId));
        installedPackages.put(installationId, {
            id = installationId;
            name = ourHalfInstalled.name;
            package = ourHalfInstalled.package;
            version = ourHalfInstalled.package.base.version; // TODO: needed?
            modules = Buffer.toArray(ourHalfInstalled.modules);
            packageCanister = ourHalfInstalled.packageCanister;
            var extraModules = [];
        });
        halfInstalledPackages.delete(installationId);
        switch (installedPackagesByName.get(ourHalfInstalled.package.base.name)) {
            case (?ids) {
                installedPackagesByName.put(ourHalfInstalled.package.base.name, Array.append(ids, [installationId]));
            };
            case null {
                installedPackagesByName.put(ourHalfInstalled.package.base.name, [installationId]);
            };
        };
    };

    /// Intended to use only in bootstrapping.
    ///
    /// TODO: Should we disable calling this after bootstrapping finished?
    public shared({caller}) func installModule(wasmModule: Common.Module, installArg: Blob): async Principal {
        onlyOwner(caller);

        await* Install._installModule(wasmModule, installArg, getIndirectCaller());
    };

    public shared({caller}) func _installModules(wasmModules: [Common.Module], installArg: Blob): async () {
        onlyOwner(caller);

        for (wasmModule in wasmModules.vals()) {
            // TODO: ignore?
            ignore await* Install._installModule(wasmModule, installArg, getIndirectCaller());
        };
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-reability, it installed partially.
    public shared({caller}) func installNamedModules(
        installationId: Common.InstallationId,
        name: ?Text,
        installArg: Blob,
        avoidRepeated: Bool,
    ): async () {
        onlyOwner(caller);

        let ?installation = installedPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        let package = installation.package;
       
        switch (package.specific) {
            case (#real package) {
                let iter = Iter.filter(package.extraModules.vals(), func((t, _): (?Text, [Common.Module])): Bool = t==name);
                let wasmModules0 = iter.next();
                if (avoidRepeated) {
                    if (iter.next() != null) {
                        Debug.trap("repeated install");
                    };
                };
                let ?wasmModules = wasmModules0 else {
                    Debug.trap("no such named modules");
                };
                for (wasmModule in wasmModules.1.vals()) {
                    ignore await* Install._installModule(wasmModule, installArg, getIndirectCaller()); // TODO: ignore?
                };
            };
            case (#virtual _) {
                Debug.trap("cannot install modules on a virtual package");
            };
        };
    };

    public shared({caller}) func uninstallPackage(installationId: Common.InstallationId)
        : async ()
    {
        // onlyOwner(caller); // FIXME

        let ?package = installedPackages.get(installationId) else {
            Debug.trap("no such installed package");
        };
        let part: RepositoryPartition.RepositoryPartition = actor (Principal.toText(package.packageCanister));
        let packageInfo = await part.getPackage(package.name, package.version);

        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = Array.size(package.modules);
            name = package.name;
            version = package.version;
            modules = Buffer.fromArray(package.modules);
            package = packageInfo;
            packageCanister = package.packageCanister;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        // TODO:
        // let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
        // let package = await part.getPackage(packageName, version);
        let #real realPackage = packageInfo.specific else {
            Debug.trap("trying to directly install a virtual package");
        };

        await* _finishUninstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
        });
    };

    type CanisterDeletor = actor {
        stop_canister : shared { canister_id : Common.canister_id } -> async ();
        delete_canister : shared { canister_id : Common.canister_id } -> async ();
    };

    private func _finishUninstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
    }): async* () {
        let IC: CanisterDeletor = actor("aaaaa-aa");
        while (ourHalfInstalled.modules.size() != 0) {
            let canister = ourHalfInstalled.modules.get(ourHalfInstalled.modules.size() - 1);
            await IC.stop_canister({canister_id = canister}); // FIXME: can hang?
            await IC.delete_canister({canister_id = canister});
            ignore ourHalfInstalled.modules.removeLast();
        };
        installedPackages.delete(installationId);
        let ?byName = installedPackagesByName.get(ourHalfInstalled.name) else {
            Debug.trap("programming error");
        };
        // TODO: The below is inefficient and silly, need to change data structure?
        if (Array.size(byName) == 1) {
            installedPackagesByName.delete(ourHalfInstalled.name);
        } else {
            let new = Iter.filter(byName.vals(), func (e: Common.InstallationId): Bool {
                e != installationId;
            });
            installedPackagesByName.put(ourHalfInstalled.name, Iter.toArray(new));
        };
        halfInstalledPackages.delete(installationId);
    };

     /// Finish installation of a half-installed package.
    public shared({caller}) func finishUninstallPackage({installationId: Nat}): async () {
        onlyOwner(caller);
        
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package uninstallation has not been started");
        };
        let #real realPackage = ourHalfInstalled.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        await* _finishUninstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
        });
    };

   system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());

        _installedPackagesSave := Iter.toArray(installedPackages.entries());

        _installedPackagesByNameSave := Iter.toArray(installedPackagesByName.entries());

        // TODO:
        // _halfInstalledPackagesSave := Iter.toArray(Iter.map(
        //     halfInstalledPackages,
        //     {
        //         shouldHaveModules: Nat;
        //         name: Common.PackageName;
        //         version: Common.Version;
        //         modules: [Principal];
        //     }
        // ));
    };

    system func postupgrade() {
        owners := HashMap.fromIter(
            _ownersSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _ownersSave := []; // Free memory.

        installedPackages := HashMap.fromIter(
            _installedPackagesSave.vals(),
            Array.size(_installedPackagesSave),
            Nat.equal,
            Int.hash,
        );
        _installedPackagesSave := []; // Free memory.

        installedPackagesByName := HashMap.fromIter(
            _installedPackagesByNameSave.vals(),
            Array.size(_installedPackagesByNameSave),
            Text.equal,
            Text.hash,
        );
        _installedPackagesByNameSave := []; // Free memory.

        // halfInstalledPackages := TODO;
        _halfInstalledPackagesSave := []; // Free memory.
    };

    // Accessor method //

    public query func getInstalledPackage(id: Common.InstallationId): async Common.SharedInstalledPackageInfo {
        let ?result = installedPackages.get(id) else {
            Debug.trap("no such installed package");
        };
        result;
    };

    /// TODO: very unstable API.
    public query func getInstalledPackagesInfoByName(name: Text): async [Common.SharedInstalledPackageInfo] {
        let ?ids = installedPackagesByName.get(name) else {
            return [];
        };
        Iter.toArray(Iter.map(ids.vals(), func (id: Common.InstallationId): Common.InstalledPackageInfo {
            let ?info = installedPackages.get(id) else {
                Debug.trap("programming error");
            };
            info;
        }));
    };

    /// TODO: very unstable API.
    public query func getAllInstalledPackages(): async [(Common.InstallationId, Common.SharedInstalledPackageInfo)] {
        Iter.toArray(installedPackages.entries());
    };

    /// TODO: very unstable API.
    public query func getHalfInstalledPackages(): async [{
        installationId: Common.InstallationId;
        packageCanister: Principal;
        name: Common.PackageName;
        version: Common.Version;
    }] {
        Iter.toArray(Iter.map<(Common.InstallationId, Common.HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            packageCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        }>(halfInstalledPackages.entries(), func (x: (Common.InstallationId, Common.HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            packageCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        } =
            {
                installationId = x.0;
                packageCanister = x.1.packageCanister;
                name = x.1.name;
                version = x.1.version;
            },
        ));
    };

    // TODO: Copy package specs to "userspace", in order to have `extraModules` fixed for further use.

    public shared({caller}) func installExtraModules(extraModules: [Common.Module]): async () {
        onlyOwner(caller);

        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        // FIXME
        for (wasmModule in extraModules.vals()) {
            Cycles.add<system>(10_000_000_000_000); // FIXME
            let {canister_id} = await IC.create_canister({
                settings = ?{
                    freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                    controllers = ?[Principal.fromActor(this), Principal.fromActor(getIndirectCaller())];
                    compute_allocation = null; // TODO
                    memory_allocation = null; // TODO (a low priority task)
                }
            });
            let installArg = to_candid({
                user = caller;
                // previousCanisters = Buffer.toArray(ourHalfInstalled.modules); // TODO
                packageManager = this;
            });
            ignore await* Install._installModule(wasmModule, installArg, getIndirectCaller()); // TODO: ignore?
        };
    };

    // Convenience methods //

    public shared({caller}) func addRepository(canister: Principal, name: Text): async () {
        // FIXME: Check caller.
        repositories := Array.append(repositories, [{canister; name}]);
    };

    public shared({caller}) func removeRepository(canister: Principal): async () {
        // FIXME: Check caller.
        repositories := Iter.toArray(Iter.filter(
            repositories.vals(),
            func (x: {canister: Principal; name: Text}): Bool = x.canister != canister));
    };

    public query func getRepositories(): async [{canister: Principal; name: Text}] {
        repositories;
    };

    // Callbacks //

    public shared({caller}) func copyAssetsCallback({from: Asset.AssetCanister; to: Asset.AssetCanister}) {
        if (caller != Principal.fromActor(getIndirectCaller())) {
            Debug.trap("only by indirect_caller_");
        };

        await* CopyAssets.copyAll({from; to});
    }
}