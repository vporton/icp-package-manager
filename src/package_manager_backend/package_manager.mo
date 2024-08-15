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
import Asset "mo:assets-api";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import CopyAssets "../copy_assets";
import IndirectCaller "indirect_caller";

/// TODO: Methods to query for all installed packages.
shared({caller = initialOwner}) actor class PackageManager() = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

    // FIXME: UUID prefix to init and conform to API.
    public shared({caller}) func init(packageCanister: Principal, version: Common.Version, modules: [Principal])
        : async ()
    {
        onlyOwner(caller);

        let indirect_caller_v = await IndirectCaller.IndirectCaller();
        indirect_caller := ?indirect_caller_v;
        Cycles.add<system>(5_000_000_000_000); // FIXME
        let IC = actor ("aaaaa-aa") : actor {
            deposit_cycles : shared { canister_id : canister_id } -> async ();
        };
        await IC.deposit_cycles({ canister_id = Principal.fromActor(indirect_caller_v) });

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        let part: Common.RepositoryPartitionRO = actor (Principal.toText(packageCanister));
        let package = await part.getPackage("package-manager", version);
        let numPackages = Array.size(modules);
        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = numPackages;
            name = "package-manager";
            version = version;
            modules = Buffer.fromArray(modules); // Pretend that our package's modules are already installed.
            package;
            packageCanister;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        _updateAfterInstall({installationId});

        // owners := HashMap.fromIter([(user, ())].vals(), 1, Principal.equal, Principal.hash);
    };

    stable var indirect_caller: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller2 = indirect_caller else {
            Debug.trap("indirect_caller not initialized");
        };
        indirect_caller2;
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
    var halfInstalledPackages: HashMap.HashMap<Common.InstallationId, Common.HalfInstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Int.hash);

    stable var repositories: [{canister: Principal; name: Text}] = []; // TODO: a more suitable type like `HashMap` or at least `Buffer`?

    func onlyOwner(caller: Principal) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner");
        }
    };

    type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    type canister_id = Principal;
    type wasm_module = Blob;

    type CanisterCreator = actor {
        create_canister : shared { settings : ?canister_settings } -> async {
            canister_id : canister_id;
        };
        install_code : shared {
            arg : [Nat8];
            wasm_module : wasm_module;
            mode : { #reinstall; #upgrade; #install };
            canister_id : canister_id;
        } -> async ();
    };

    /// We don't install dependencies here (see `specs.odt`).
    public shared({caller}) func installPackage({
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
    })
        : async Common.InstallationId
    {
        // onlyOwner(caller); // FIXME

        let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
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

        await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
        });

        installationId;
    };

    /// Finish installation of a half-installed package.
    public shared({caller}) func finishInstallPackage({installationId: Nat}): async () {
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
        });
    };

    private func _finishInstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
        caller: Principal;
    }): async* () {
        let IC: CanisterCreator = actor("aaaaa-aa");

        // let canisters = Buffer.Buffer<Principal>(numPackages);
        // TODO: Don't wait for creation of a previous canister to create the next one.
        for (wasmModule in realPackage.modules.vals()) {
            // TODO: cycles (and monetization)
            Cycles.add<system>(10_000_000_000_000);
            let {canister_id} = await IC.create_canister({
                settings = ?{
                    freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                    controllers = ?[Principal.fromActor(this), Principal.fromActor(getIndirectCaller())];
                    compute_allocation = null; // TODO
                    memory_allocation = null; // TODO (a low priority task)
                }
            });
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
                previousCanisters = Buffer.toArray(ourHalfInstalled.modules);
                packageManager = this;
            });
            switch (wasmModule) {
                case (#Assets {assets}) {
                    getIndirectCaller().callAll([
                        {
                            canister = Principal.fromActor(IC);
                            name = "install_code";
                            data = to_candid({
                                arg = Blob.toArray(installArg);
                                wasm_module;
                                mode = #install;
                                canister_id;
                            });
                        },
                        {
                            canister = Principal.fromActor(getIndirectCaller());
                            name = "copyAssetsCallback";
                            data = to_candid({
                                from = assets; to = actor(Principal.toText(canister_id)): Asset.AssetCanister;
                            });
                        }
                    ]);
                };
                case _ {
                    // TODO: Remove this code after debugging the below.
                    // await IC.install_code({
                    //     arg = Blob.toArray(installArg);
                    //     wasm_module;
                    //     mode = #install;
                    //     canister_id;
                    // });
                    getIndirectCaller().callAll([
                        {
                            canister = Principal.fromActor(IC);
                            name = "install_code";
                            data = to_candid({
                                arg = Blob.toArray(installArg);
                                wasm_module;
                                mode = #install;
                                canister_id;
                            });
                        },
                    ]);
                };
            };
            // canisters.add(canister_id); // do it later.
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
    };

    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        installedPackages.put(installationId, {
            id = installationId;
            name = ourHalfInstalled.package.base.name;
            version = ourHalfInstalled.package.base.version;
            modules = Buffer.toArray(ourHalfInstalled.modules);
            packageCanister = ourHalfInstalled.packageCanister;
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
        stop_canister : shared { canister_id : canister_id } -> async ();
        delete_canister : shared { canister_id : canister_id } -> async ();
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

    public query func getInstalledPackage(id: Common.InstallationId): async Common.InstalledPackageInfo {
        let ?result = installedPackages.get(id) else {
            Debug.trap("no such installed package");
        };
        result;
    };

    /// TODO: very unstable API.
    public query func getInstalledPackagesInfoByName(name: Text): async [Common.InstalledPackageInfo] {
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
    public query func getAllInstalledPackages(): async [(Common.InstallationId, Common.InstalledPackageInfo)] {
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
            Debug.trap("only by indirect_caller");
        };

        await* CopyAssets.copyAll({from; to});
    }
}