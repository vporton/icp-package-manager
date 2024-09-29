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
import Option "mo:base/Option";
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import IndirectCaller "indirect_caller";
import Install "../install";

/// TODO: Methods to query for all installed packages.
shared({caller = initialOwner}) actor class PackageManager() = this {
    Debug.print("initialOwner = " # Principal.toText(initialOwner));

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

    // TODO: more flexible control of owners
    public shared({caller}) func setOwner(newOwner: Principal): async () {
        owners := HashMap.fromIter([(newOwner, ())].vals(), 1, Principal.equal, Principal.hash);
    };

    var initialized: Bool = false; // intentionally non-stable // FIXME: Being non-stable may be an error.

    // TODO: needed?
    // public shared({caller}) func b44c4a9beec74e1c8a7acbe46256f92f_init(
    //     {indirect_caller: IndirectCaller.IndirectCaller; arg: {frontend: Principal}} // TODO: Twice `arg` is counter-intuitive.
    // ) : async () {
    //     ignore Cycles.accept<system>(10_000_000_000_000);
    //     onlyOwner(caller);

    //     indirect_caller_ := ?indirect_caller;
    //     let IC = actor ("aaaaa-aa") : actor {
    //         deposit_cycles : shared { canister_id : Common.canister_id } -> async ();
    //     };
    //     Cycles.add<system>(5_000_000_000_000);
    //     await IC.deposit_cycles({ canister_id = Principal.fromActor(indirect_caller) });

    //     // TODO: Store among registered modules (not as named modules, because installPackageWithPreinstalledModules already does)
    //     //       itself and PM frontend.

    //     initialized := true; // TODO: Re-enable this assignment.
    // };

    // TODO
    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
    };

    // TODO: Join into a single var.
    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller_2 = indirect_caller_ else {
            Debug.trap("indirect_caller_ not initialized");
        };
        indirect_caller_2;
    };

    public shared func setIndirectCaller(indirect_caller_v: IndirectCaller.IndirectCaller): async () {
        indirect_caller_ := ?indirect_caller_v;
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
        : async {installationId: Common.InstallationId; canisterIds: [(Text, Principal)]}
    {
        onlyOwner(caller);

        await* _installPackage({caller; canister; packageName; version; preinstalledModules = null});
    };

    public shared({caller}) func installPackageWithPreinstalledModules({
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: [(Text, Principal)];
    })
        : async {installationId: Common.InstallationId; canisterIds: [(Text, Principal)]}
    {
        onlyOwner(caller);

        await* _installPackage({caller; canister; packageName; version; preinstalledModules = ?preinstalledModules});
    };

    /// We don't install dependencies here (see `specs.odt`).
    private func _installPackage({
        caller: Principal;
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: ?[(Text, Principal)];
    })
        : async* {installationId: Common.InstallationId; canisterIds: [(Text, Principal)]} // TODO: Precreate and return canister IDs.
    {
        let installationId = nextInstallationId;
        nextInstallationId += 1;

        let ?installation = installedPackages.get(installationId) else { // FIXME: This is a wrong place for this code!
            Debug.trap("no such package");
        };
        let package = installation.package;
        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };

        let numPackages = Array.size(realPackage.modules);
        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = numPackages;
            // id = installationId;
            name = package.base.name;
            version = package.base.version;
            modules = OrderedHashMap.OrderedHashMap<Text, (Principal, {#empty; #installed})>(numPackages, Text.equal, Text.hash);
            // packageDescriptionIn = part;
            package;
            packageCanister = canister;
            preinstalledModules;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        // TODO: Also correctly create canisters if installation was interrupted.
        let canisterIds = Buffer.Buffer<(Text, Principal)>(realPackage.modules.size());
        // TODO: Don't wait for creation of a previous canister to create the next one.
        label create for ((moduleName, wasmModule) in realPackage.modules.vals()) {
            let created = Option.isSome(ourHalfInstalled.modules.get(moduleName));
            if (created) {
                continue create;
            };
            let canister_id = switch (preinstalledModules) {
                case (?preinstalledModules) {
                    // assert preinstalledModules.size() == realPackage.modules.size(); // TODO: correct?
                    let ?canister_id = installation.modules.get(moduleName) else {
                        Debug.trap("programming error");
                    };
                    canister_id;
                };
                case null {
                    Cycles.add<system>(10_000_000_000_000);
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
            // TODO: Are two lines below duplicates of each other?
            ourHalfInstalled.modules.put(moduleName, (canister_id, #empty));
            canisterIds.add((moduleName, canister_id)); // do it later.
        };

        getIndirectCaller().callAllOneWay([{
            canister = Principal.fromActor(this);
            name = "installPackageWrapper";
            data = to_candid({
                installationId;
                canister;
                packageName;
                version;
           });
        }]);

        {installationId; canisterIds = Buffer.toArray(canisterIds)};
    };

    public shared({caller}) func installPackageCallback({
        installationId: Common.InstallationId;
        canister: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        package: Common.PackageInfo;
    }): async () {
        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such installation");
        };

        await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
            preinstalledModules = switch(ourHalfInstalled.preinstalledModules) {
                case (?preinstalledModules) {
                    ?(HashMap.fromIter<Text, Principal>(preinstalledModules.vals(), preinstalledModules.size(), Text.equal, Text.hash));
                };
                case null null;
            };
        });
    };  

    /// Finish installation of a half-installed package.
    public shared({caller}) func finishInstallPackage({
        installationId: Nat;
    }): async () {
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

    // TODO: Keep registry of ALL installed modules.
    private func _finishInstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
        caller: Principal;
    }): async* () {
        label install for ((moduleName, wasmModule) in realPackage.modules.vals()) {
            let ?state = ourHalfInstalled.modules.get(moduleName) else {
                Debug.trap("programming error");
            };
            if (state.1 == #installed) {
                continue install;
            };
            let installArg = to_candid({
                arg = to_candid({}); // TODO: correct?
            });
            if (Option.isNull(ourHalfInstalled.preinstalledModules)) {
                let canister = await* Install._installModule(wasmModule, to_candid(()), ?installArg, getIndirectCaller(), Principal.fromActor(this), installationId);
                getIndirectCaller().callIgnoringMissingOneWay(
                    [{
                        canister;
                        name = Common.NamespacePrefix # "init";
                        data = to_candid({
                            user = caller;
                            modules = Iter.toArray(Iter.map<(Text, (Principal, {#empty; #installed})), (Text, Principal)>(
                                ourHalfInstalled.modules.entries(),
                                func ((x, (y, z)): (Text, (Principal, {#empty; #installed}))) = (x, y),
                            ));
                            packageManager = this; // TODO: non-standard arguments?
                        });
                    }],
                );
            }/* else {
                // We don't need to initialize installed module, because it can be only
                // PM's frontend.
            }*/;
        };

        _updateAfterInstall({installationId});
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
            modules = OrderedHashMap.fromIter(Iter.map<(Text, (Principal, {#empty; #installed})), (Text, Principal)>(
                ourHalfInstalled.modules.entries(),
                func ((x, (y, z)): (Text, (Principal, {#empty; #installed}))) = (x, y),
            ), ourHalfInstalled.modules.size(), Text.equal, Text.hash);
            packageCanister = ourHalfInstalled.packageCanister;
            extraModules = Buffer.Buffer(0);
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
    // public shared({caller}) func installModule(wasmModule: Common.Module, installArg: Blob, initArg: ?Blob): async Principal {
    //     onlyOwner(caller);

    //     await* Install._installModule(wasmModule, installArg, initArg, getIndirectCaller(), Principal.fromActor(this));
    // };

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
                    ignore await* Install._installNamedModule(wasmModule, installArg, initArg, getIndirectCaller(), Principal.fromActor(this), installationId, m.0);
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

        let ?installation = installedPackages.get(installationId) else {
            Debug.trap("no such installed installation");
        };
        let part: RepositoryPartition.RepositoryPartition = actor (Principal.toText(installation.packageCanister));
        let packageInfo = await part.getPackage(installation.name, installation.version);

        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = installation.modules.size(); // TODO: Is it a nonsense?
            name = installation.name;
            version = installation.version;
            modules = OrderedHashMap.fromIter( // TODO: can be made simpler?
                Iter.map<(Text, Principal), (Text, (Principal, {#empty; #installed}))>(
                    installation.modules.entries(),
                    func ((x, y): (Text, Principal)) = (x, (y, #installed))
                ),                
                installation.modules.size(),
                Text.equal,
                Text.hash,
            );
            package = packageInfo;
            packageCanister = installation.packageCanister;
            preinstalledModules = null; // TODO: Seems right, but check again.
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        // TODO:
        // let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
        // let installation = await part.getPackage(packageName, version);
        let #real realPackage = packageInfo.specific else {
            Debug.trap("trying to directly install a virtual installation");
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
            let canister_id = vals[vals.size() - 1].0;
            getIndirectCaller().callAllOneWay([
                {
                    canister = Principal.fromActor(IC);
                    name = "stop_canister";
                    data = to_candid({canister_id});
                },
                {
                    canister = Principal.fromActor(IC);
                    name = "delete_canister";
                    data = to_candid({canister_id});
                },
            ]);
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
        onlyOwner(caller);

        repositories := Array.append(repositories, [{canister; name}]); // TODO: Use `Buffer` instead.
    };

    public shared({caller}) func removeRepository(canister: Principal): async () {
        onlyOwner(caller);

        repositories := Iter.toArray(Iter.filter(
            repositories.vals(),
            func (x: {canister: Principal; name: Text}): Bool = x.canister != canister));
    };

    public query func getRepositories(): async [{canister: Principal; name: Text}] {
        repositories;
    };
}