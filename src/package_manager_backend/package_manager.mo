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
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import IndirectCaller "indirect_caller";
import Install "../install";

/// TODO: Methods to query for all installed packages.
shared({caller = initialOwner}) actor class PackageManager() = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

    var initialized: Bool = false; // intentionally non-stable

    // FIXME: UUID prefix to init and conform to API.
    // FIXME: Check function signature:
    public shared({caller}) func init(arg: {indirect_caller: IndirectCaller.IndirectCaller}) : async () {
        ignore Cycles.accept<system>(10_000_000_000_000); // TODO
        onlyOwner(caller);

        indirect_caller_ := ?arg.indirect_caller;
        let IC = actor ("aaaaa-aa") : actor {
            deposit_cycles : shared { canister_id : Common.canister_id } -> async ();
        };
        Cycles.add<system>(5_000_000_000_000); // FIXME
        await IC.deposit_cycles({ canister_id = Principal.fromActor(arg.indirect_caller) });

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

        initialized := true;
    };

    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
    };

    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller_2 = indirect_caller_ else {
            Debug.trap("indirect_caller_ not initialized");
        };
        indirect_caller_2;
    };

    stable var nextInstallationId: Nat = 0;

    stable var _installedPackagesSave: [(Common.InstallationId, Common.SharedInstalledPackageInfo)] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo> =
        HashMap.HashMap(0, Nat.equal, Int.hash);

    stable var _installedPackagesByNameSave: [(Common.PackageName, [Common.InstallationId])] = [];
    var installedPackagesByName: HashMap.HashMap<Common.PackageName, [Common.InstallationId]> =
        HashMap.HashMap(0, Text.equal, Text.hash);

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
        preinstalledModules: [(Text, Common.Location)];
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
        preinstalledModules: ?[(Text, Common.Location)];
    })
        : async* {installationId: Common.InstallationId; canisterIds: [Principal]}
    {
        let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
        // FIXME: Here and in other places, a hacker may make PM non-upgradeable.
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
            modules = OrderedHashMap.OrderedHashMap<Text, Principal>(numPackages, Text.equal, Text.hash);
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
        preinstalledModules: ?[(Text, Common.Location)];
    }): async* {canisterIds: [Principal]} {
        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        let canisterIds = Buffer.Buffer<Principal>(realPackage.modules.size());
        // TODO: Don't wait for creation of a previous canister to create the next one.
        // FIXME: It makes sense to create all the canisters before installing WASM.
        for (i in Iter.range(0, realPackage.modules.size() - 1)) {
            let (moduleName, wasmModule) = realPackage.modules[i];
            Cycles.add<system>(10_000_000_000_000); // TODO
            let canister_id = switch (preinstalledModules) {
                case (?preinstalledModules) {
                    assert preinstalledModules.size() == realPackage.modules.size();
                    preinstalledModules[i].1.0;
                };
                case null {
                    let {canister_id} = await IC.create_canister({
                        settings = ?{
                            freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                            controllers = ?[Principal.fromActor(getIndirectCaller())]; // No package manager as a controller, because the PM may be upgraded.
                            compute_allocation = null; // TODO
                            memory_allocation = null; // TODO (a low priority task)
                        }
                    });
                    canister_id;
                };
            };
            let installArg = to_candid({ // FIXME: In different places different args.
                user = caller;
                previousCanisters = Iter.toArray<(Text, Principal)>(ourHalfInstalled.modules.entries()); // TODO: We can create all canisters first and pass all, not just previous.
                packageManager = this;
            });
            if (preinstalledModules == null) {
                // TODO: ignore?
                ignore await* Install._installModule(wasmModule, to_candid(()), ?installArg, getIndirectCaller(), ?(Principal.fromActor(this)));
            }/* else {
                // We don't need to initialize installed module, because it can be only
                // PM's frontend.
            }*/;
            // TODO: Are two lines below duplicates of each other?
            canisterIds.add(canister_id); // do it later.
            ourHalfInstalled.modules.put(moduleName, canister_id);
        };
        // FIXME: Add this back after making creating all canisters before installing WASM.
        // getIndirectCaller().callIgnoringMissingOneWay(
        //     Iter.toArray(Iter.map<Nat, {canister: Principal; name: Text; data: Blob}>(
        //         Iter.toArray<(Text, Principal)>(ourHalfInstalled.modules.entries()), // TODO: inefficient?
        //         func (i: Nat) = {
        //             canister = ourHalfInstalled.modules.get(i).1;
        //             name = Common.NamespacePrefix # "init";
        //             data = to_candid({
        //                 user = caller;
        //                 previousCanisters = Array.subArray<(Text, Principal)>(Buffer.toArray(ourHalfInstalled.modules), 0, i);
        //                 packageManager = this;
        //             });
        //         },
        //     )),
        // );

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
            modules = ourHalfInstalled.modules;
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
    public shared({caller}) func installModule(wasmModule: Common.Module, installArg: Blob, initArg: ?Blob): async Principal {
        onlyOwner(caller);

        await* Install._installModule(wasmModule, installArg, initArg, getIndirectCaller(), ?(Principal.fromActor(this)));
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-reability, it installed partially.
    public shared({caller}) func installNamedModules(
        installationId: Common.InstallationId,
        modules: [(Text, Blob, ?Blob)], // name, installArg, initArg
        avoidRepeated: Bool,
    ): async () {
        onlyOwner(caller);

        let ?installation = installedPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        let package = installation.package;

        // TODO: Don't install already installed.
        let modules0 = Iter.map<(Text, Blob, ?Blob), (Text, (Blob, ?Blob))>(
            modules.vals(),
            func(x: (Text, Blob, ?Blob)): (Text, (Blob, ?Blob)) = (x.0, (x.1, x.2)));
        let modules2 = HashMap.fromIter<Text, (Blob, ?Blob)>(modules0, Array.size(modules), Text.equal, Text.hash);
        switch (package.specific) {
            case (#real package) {
                let extraModules2 = HashMap.fromIter<Text, Common.Module>(package.extraModules.vals(), Array.size(modules), Text.equal, Text.hash);
                for (m in modules0) {
                    let ?wasmModule = extraModules2.get(m.0) else {
                        Debug.trap("no extra module '" # m.0 # "'");
                    };
                    let ?(installArg, initArg) = modules2.get(m.0) else {
                        Debug.trap("programming error");
                    };
                    // FIXME: Update installed modules data. It will be used to initialize more modules.
                    ignore await* Install._installModule(wasmModule, installArg, initArg, getIndirectCaller(), ?(Principal.fromActor(this))); // TODO: ignore?
                };
                if (avoidRepeated) {
                    // TODO: wrong condition
                    // if (iter.next() != null) {
                    //     Debug.trap("repeated install");
                    // };
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
        onlyOwner(caller);

        let ?package = installedPackages.get(installationId) else {
            Debug.trap("no such installed package");
        };
        let part: RepositoryPartition.RepositoryPartition = actor (Principal.toText(package.packageCanister));
        let packageInfo = await part.getPackage(package.name, package.version);

        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = package.modules.size(); // FIXME: Is it a nonsense?
            name = package.name;
            version = package.version;
            modules = package.modules; // FIXME: (here and in other places) create a deep copy.
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
            let vals = Iter.toArray(ourHalfInstalled.modules.vals()); // TODO: slow
            let canister_id = vals[vals.size() - 1];
            await IC.stop_canister({canister_id}); // FIXME: can hang?
            await IC.delete_canister({canister_id});
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

        _installedPackagesSave := Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(installedPackages.entries(), func ((id, info): (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) {
                (id, Common.installedPackageInfoShare(info));
            }
        ));

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

        installedPackages := HashMap.fromIter<Common.InstallationId, Common.InstalledPackageInfo>(
            Iter.map<(Common.InstallationId, Common.SharedInstalledPackageInfo), (Common.InstallationId, Common.InstalledPackageInfo)>(
                _installedPackagesSave.vals(),
                func ((id, info): (Common.InstallationId, Common.SharedInstalledPackageInfo)): (Common.InstallationId, Common.InstalledPackageInfo) {
                    (id, Common.installedPackageInfoUnshare(info));
                },
            ),Array.size(_installedPackagesSave),
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
        Common.installedPackageInfoShare(result);
    };

    /// TODO: very unstable API.
    public query func getInstalledPackagesInfoByName(name: Text): async [Common.SharedInstalledPackageInfo] {
        let ?ids = installedPackagesByName.get(name) else {
            return [];
        };
        // TODO: Eliminiate duplicate code:
        Iter.toArray(Iter.map(ids.vals(), func (id: Common.InstallationId): Common.SharedInstalledPackageInfo {
            let ?info = installedPackages.get(id) else {
                Debug.trap("programming error");
            };
            Common.installedPackageInfoShare(info);
        }));
    };

    /// TODO: very unstable API.
    public query func getAllInstalledPackages(): async [(Common.InstallationId, Common.SharedInstalledPackageInfo)] {
        Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(
                installedPackages.entries(),
                func (info: (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) =
                    (info.0, Common.installedPackageInfoShare(info.1))
            )
        );
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
}