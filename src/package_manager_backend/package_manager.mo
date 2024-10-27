/// TODO: Methods to query for all installed packages.
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
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import IndirectCaller "indirect_caller";
import Install "../install";
import cycles_ledger "canister:cycles_ledger";

shared({/*caller = initialOwner*/}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    userArg: Blob;
}) = this {
    let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
        initialIndirectCaller: Principal; // TODO: Rename.
    } = from_candid(userArg) else {
        Debug.trap("argument userArg is wrong");
    };

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(packageManagerOrBootstrapper, ()), (userArgValue.initialIndirectCaller, ())].vals(), 1, Principal.equal, Principal.hash);

    // TODO: more flexible control of owners
    public shared({caller}) func setOwner(newOwner: Principal): async () {
        onlyOwner(caller, "setOwner");

        owners := HashMap.fromIter([(newOwner, ())].vals(), 1, Principal.equal, Principal.hash);
    };

    // TODO: Remove.
    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
    };

    var initialized: Bool = false; // intentionally non-stable // TODO: separate variable for signaling upgrading?

    // TODO: needed? // FIXME: `onlyOwner`
    // TODO: indirectCaller set at an earlier stage with `setIndirectCaller()`
    public shared({caller}) func b44c4a9beec74e1c8a7acbe46256f92f_init({
        user: Principal;
        indirect_caller: Principal;
    }) : async () {
        Debug.print("initializing package manager");

        indirect_caller_ := ?actor(Principal.toText(indirect_caller));
        owners := HashMap.fromIter([(user, ())].vals(), 1, Principal.equal, Principal.hash);

        initialized := true;
    };

    // TODO
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

    // TODO: too low-level?
    public shared({caller}) func setIndirectCaller(indirect_caller_v: IndirectCaller.IndirectCaller): async () {
        onlyOwner(caller, "setIndirectCaller");

        indirect_caller_ := ?indirect_caller_v;
    };

    stable var nextInstallationId: Nat = 1; // 0 is reserved for bootstrapper (HACK)

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

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        }
    };

    public shared({caller}) func installPackage({
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryPartitionRO;
        user: Principal;
    })
        : async {installationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackage");

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        await* _installModulesGroup({
            installPackage = true;
            pmPrincipal = ?Principal.fromActor(this);
            repo;
            objectToInstall = #package {packageName; version};
            user;
            preinstalledModules = [];
        });
    };

    /// Internal used for bootstrapping.
    public shared({caller}) func installPackageWithPreinstalledModules({
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: [(Text, Principal)];
        repo: Common.RepositoryPartitionRO;
        user: Principal;
    })
        : async {installationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackageWithPreinstalledModules");

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        await* _installModulesGroup({
            installPackage = true;
            pmPrincipal = ?Principal.fromActor(this);
            repo;
            objectToInstall = #package {packageName; version};
            user;
            preinstalledModules;
        });
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-realiability, it installed partially.
    /// FIXME: This should be combined with package installation.
    public shared({caller}) func installNamedModules(
        installationId: Common.InstallationId,
        modules: [(Text, Blob, ?Blob)], // name, installArg, initArg
        avoidRepeated: Bool,
    ): async () {
        onlyOwner(caller, "installNamedModule");

        await* _installModulesGroup({
            pmPrincipal = ?Principal.fromActor(this);
            repo: Common.RepositoryPartitionRO;
            objectToInstall = #package {packageName; version};
            user;
            preinstalledModules;
        });
    };

    type ObjectToInstall = {
        #package : {
            packageName: Common.PackageName;
            version: Common.Version;
        };
        #namedModules : {
            dest: Common.InstallationId;
            modules: [(Text, Blob, ?Blob)]; // name, installArg, initArg
        };
    };

    /// Does most of the work of installing a package.
    public shared({caller}) func installationWorkCallback({ // callback 1 // TODO
        installPackage: Bool; /// install package or named modules.
        installationId: Common.InstallationId;
        // createdCanister: Principal;
        user: Principal;
        package: Common.PackageInfo;
        indirectCaller: IndirectCaller.IndirectCaller;
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryPartitionRO;
        preinstalledModules: ?[(Text, Principal)];
    }): async () {
        Debug.print("installationWorkCallback");

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
            packageCanister = Principal.fromActor(d.repo);
            preinstalledModules = d.preinstalledModules;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        let installation: Common.InstalledPackageInfo = {
            id = installationId;
            name = d.packageName;
            package;
            packageCanister = Principal.fromActor(d.repo);
            version = d.version;
            modules = OrderedHashMap.OrderedHashMap<Text, Principal>(Array.size(realPackage.modules), Text.equal, Text.hash);
            // extraModules = Buffer.Buffer<(Text, Principal)>(Array.size(realPackage.extraModules));
            allModules = Buffer.Buffer<Principal>(0); // 0?
        };

        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        // TODO: Also correctly create canisters if installation was interrupted.
        let canisterIds = Buffer.Buffer<(Text, Principal)>(realPackage.modules.size());
        // TODO: Don't wait for creation of a previous canister to create the next one.
        label create for ((moduleName, wasmModule) in realPackage.modules.vals()) {
            let created = Option.isSome(ourHalfInstalled.modules.get(moduleName));
            if (not created) { // TODO: If all are created...
                getIndirectCaller().installModule(TODO);
            };
            // FIXME: Move to `updateModule`:
            ourHalfInstalled.modules.put(moduleName, (canister_id, #empty));
            canisterIds.add((moduleName, canister_id)); // do it later.
        };
    };  

    // FIXME: Rewrite.
    /// Internal
    public shared({caller}) func onCreateCanister({
        installPackage: Bool;
        installationId: Common.InstallationId;
        installingModules: [(Text, Module)];
        canister: Principal;
        user: Principal;
    }): async* () {
        if (caller != Principal.fromActor(getIndirectCaller())) { // TODO
            Debug.trap("callback not by indirect_caller");
        };

        let ?inst = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package"); // better message
        };
        switch (inst.package.callbacks.get(#CanisterCreated)) {
            case (callbackName) {
                callAllOneWay([{
                    canister;
                    name = callbackName;
                    data = to_candid(); // TODO 
                }]);
            };
            case null {};
        };
        if (inst.modules.size() == installingModules.size()) { // FIXME // All module have been installed. // TODO: efficient?
            halfInstalledPackages.delete(installationId);
            _updateAfterInstall({installationId});
        };
    };

    // FIXME: Rewrite.
    /// Internal
    public shared({caller}) func onInstallCode({ // TODO: Rename here and in the diagram.
        installPackage: Bool;
        installationId: Common.InstallationId;
        installingModules: [(Text, Module)];
        user: Principal;
    }): async* () {
        if (caller != Principal.fromActor(getIndirectCaller())) { // TODO
            Debug.trap("callback not by indirect_caller");
        };

        _registerNamedModule({
            installation = installationId;
            canister;
            packageManager = Principal.fromActor(this);
            moduleName;
        });
        if (inst.modules.size() == realPackage.modules.size()) { // All module hve been installed. // TODO: efficient?
            halfInstalledPackages.delete(installationId);
            _updateAfterInstall({installationId});
        };
    };

    // TODO: Keep registry of ALL installed modules.
    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
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
            // extraModules = Buffer.Buffer<Principal>(0);
            allModules = Buffer.Buffer<Principal>(0);
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
        onlyOwner(caller, "uninstallPackage");

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
            Debug.trap("programming error: can't get package by name");
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
        onlyOwner(caller, "finishUninstallPackage");
        
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
                Debug.trap("getInstalledPackagesInfoByName: programming error");
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

    /// TODO: very unstable API.
    public query func getHalfInstalledPackageById(installationId: Common.InstallationId): async {
        packageName: Text;
        version: Common.Version;
        package: Common.PackageInfo;
    } {
        let ?res = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package")
        };
        {packageName = res.name; version = res.version; package = res.package};
    };

    // TODO: Copy package specs to "userspace", in order to have `extraModules` fixed for further use.

    // Convenience methods //

    public shared({caller}) func addRepository(canister: Principal, name: Text): async () {
        onlyOwner(caller, "addRepository");

        repositories := Array.append(repositories, [{canister; name}]); // TODO: Use `Buffer` instead.
    };

    public shared({caller}) func removeRepository(canister: Principal): async () {
        onlyOwner(caller, "removeRepository");

        repositories := Iter.toArray(Iter.filter(
            repositories.vals(),
            func (x: {canister: Principal; name: Text}): Bool = x.canister != canister));
    };

    public query func getRepositories(): async [{canister: Principal; name: Text}] {
        repositories;
    };

    // public shared({caller}) func registerNamedModule({
    //     installation: Common.InstallationId;
    //     canister: Principal;
    //     packageManager: Principal;
    //     moduleName: Text;
    // }): async () {
    //     onlyOwner(caller, "registerNamedModule");

    //     await* Install._registerNamedModule({
    //         installation;
    //         canister;
    //         packageManager;
    //         moduleName;
    //         installedPackages; // TODO: not here
    //     });
    // };

    /// We don't install dependencies here (see `specs.odt`).
    private func _installModulesGroup({
        installPackage: Bool;
        installationId: Common.InstallationId;
        pmPrincipal: ?Principal; /// `null` means that the first installed module is the PM (used in bootstrapping).
        repo: Common.RepositoryPartitionRO;
        objectToInstall: ObjectToInstall;
        user: Principal;
        preinstalledModules: [(Text, Principal)];
    })
        : async* {installationId: Common.InstallationId}
    {
        getIndirectCaller().installPackageWrapper({
            installPackage;
            installationId;
            pmPrincipal;
            repo;
            objectToInstall;
            user;
            preinstalledModules;
        });

        {installationId};
    };
}