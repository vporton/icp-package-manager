/// TODO: Methods to query for all installed packages.
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Option "mo:base/Option";
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import IndirectCaller "indirect_caller";
import Install "../install";

shared({caller = initialOwner}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    userArg: Blob;
}) = this {
    let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
        initialIndirectCaller: Principal;
    } = from_candid(userArg) else {
        Debug.trap("argument userArg is wrong");
    };

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [(packageManagerOrBootstrapper, ()), (initialOwner, ()), (userArgValue.initialIndirectCaller, ())].vals(),
            3,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        onlyOwner(caller, "setOwners");

        owners := HashMap.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Array.size(newOwners),
            Principal.equal,
            Principal.hash,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        onlyOwner(caller, "addOwner");

        owners.put(newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        onlyOwner(caller, "removeOwner");

        owners.delete(oldOwner);
    };

    // TODO: Remove.
    public query func getOwners(): async [Principal] {
        Iter.toArray(owners.keys());
    };

    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        true;
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

    stable var nextInstallationId: Nat = 0;

    stable var _installedPackagesSave: [(Common.InstallationId, Common.SharedInstalledPackageInfo)] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo> =
        HashMap.HashMap(0, Nat.equal, Common.IntHash);

    stable var _installedPackagesByNameSave: [(Common.PackageName, [Common.InstallationId])] = [];
    var installedPackagesByName: HashMap.HashMap<Common.PackageName, [Common.InstallationId]> =
        HashMap.HashMap(0, Text.equal, Text.hash);

    stable var _halfInstalledPackagesSave: [(Common.InstallationId, {
        /// The number of modules in fully installed state.
        numberOfModulesToInstall: Nat;
        name: Common.PackageName;
        version: Common.Version;
        modules: [Principal];
    })] = [];
    // TODO: `var` or `let` here and in other places:
    var halfInstalledPackages: HashMap.HashMap<Common.InstallationId, Common.HalfInstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Common.IntHash);

    stable var repositories: [{canister: Principal; name: Text}] = []; // TODO: a more suitable type like `HashMap` or at least `Buffer`?

    func onlyOwner(caller: Principal, msg: Text) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner: " # msg);
        };
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

        await* Install._installModulesGroup({
            indirectCaller = getIndirectCaller();
            whatToInstall = #package;
            installationId;
            packageName;
            packageVersion = version;
            installPackage = true;
            pmPrincipal = Principal.fromActor(this);
            repo;
            objectToInstall = #package {packageName; version};
            user;
            preinstalledModules = [];
            noPMBackendYet = false; // TODO: It seems that this argument is never true. Remove it?
        });
    };

    /// Internal used for bootstrapping.
    public shared({caller}) func installPackageWithPreinstalledModules({
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: [(Text, Principal)];
        repo: Common.RepositoryPartitionRO; 
        user: Principal;
        indirectCaller: Principal;
    })
        : async {installationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackageWithPreinstalledModules");

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        await* Install._installModulesGroup({
            indirectCaller = actor(Principal.toText(indirectCaller));
            whatToInstall;
            installationId;
            packageName;
            packageVersion = version;
            installPackage = true;
            pmPrincipal = Principal.fromActor(this);
            repo;
            objectToInstall = #package {packageName; version};
            user;
            preinstalledModules;
            noPMBackendYet = true; // TODO: check this
        });
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-realiability, it installed partially.
    public shared({caller}) func installNamedModules({
        installationId: Common.InstallationId;
        repo: Common.RepositoryPartitionRO; // TODO: Install from multiple repos.
        modules: [(Text, Common.SharedModule)]; // TODO: installArg, initArg
        _avoidRepeated: Bool; // TODO: Use.
        user: Principal;
        preinstalledModules: [(Text, Principal)];
    }): async {installationId: Common.InstallationId} {
        onlyOwner(caller, "installNamedModule");

        let ?inst = installedPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        await* Install._installModulesGroup({
            indirectCaller = getIndirectCaller();
            whatToInstall = #simplyModules modules;
            installationId;
            packageName = inst.package.base.name;
            packageVersion = inst.package.base.version;
            pmPrincipal = Principal.fromActor(this);
            repo;
            objectToInstall = #package {packageName = inst.package.base.name; version = inst.package.base.version};
            user;
            preinstalledModules;
            noPMBackendYet = false;
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
    public shared({caller}) func installationWorkCallback({
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        installationId: Common.InstallationId;
        user: Principal;
        package: Common.SharedPackageInfo;
        repo: Common.RepositoryPartitionRO;
        preinstalledModules: [(Text, Principal)];
    }): async () {
        onlyOwner(caller, "installationWorkCallback");

        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };

        let package2 = Common.unsharePackageInfo(package); // TODO: why used twice below? seems to be a mis-programming.
        let numPackages = realPackage.modules.size();

        let package3 = switch (package2.specific) {
            case (#real v) v;
            case _ {
                Debug.trap("unsupported package format");
            };
        };

        let (realModulesToInstall, realModulesToInstallSize): (Iter.Iter<(Text, Common.Module)>, Nat) = switch (whatToInstall) {
            case (#package) {
                let iter = Iter.map<(Text, (Common.Module, Bool)), (Text, Common.Module)>(
                    Iter.filter<(Text, (Common.Module, Bool))>(
                        package3.modules.entries(),
                        func ((_k, (_m, b)): (Text, (Common.Module, Bool))): Bool = b,
                    ),
                    func ((k, (m, _b)): (Text, (Common.Module, Bool))): (Text, Common.Module) = (k, m),
                );
                (iter, package3.modules.size()); // TODO: efficient?
            };
            case (#simplyModules ms) {
                let iter = Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                    ms.vals(),
                    func ((k, v): (Text, Common.SharedModule)): (Text, Common.Module) = (k, Common.unshareModule(v)),
                );
                (iter, ms.size());  // TODO: efficient?
            };
        };
        let realModulesToInstall2 = Iter.toArray(realModulesToInstall); // Iter to be used two times, convert to array.

        let preinstalledModules2 = HashMap.fromIter<Text, Principal>(
            preinstalledModules.vals(), preinstalledModules.size(), Text.equal, Text.hash);
        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            numberOfModulesToInstall = numPackages;
            // id = installationId;
            packageName = package.base.name;
            version = package.base.version;
            modules = OrderedHashMap.OrderedHashMap<Text, (Principal, {#empty; #installed})>(numPackages, Text.equal, Text.hash);
            // packageDescriptionIn = part;
            package = package2;
            packageRepoCanister = Principal.fromActor(repo);
            preinstalledModules = preinstalledModules2;
            modulesToInstall = HashMap.fromIter<Text, Common.Module>(
                realModulesToInstall2.vals(),
                realModulesToInstallSize,
                Text.equal,
                Text.hash);
            modulesWithoutCode = HashMap.HashMap(realModulesToInstallSize, Text.equal, Text.hash); // TODO: efficient?
            installedModules = HashMap.HashMap(realModulesToInstallSize, Text.equal, Text.hash); // TODO: efficient?
            whatToInstall;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);
    };

    /// Internal
    public shared({caller}) func onCreateCanister({
        installationId: Common.InstallationId;
        module_: Common.SharedModule;
        moduleName: ?Text;
        canister: Principal;
        user: Principal;
    }): async () {
        onlyOwner(caller, "onCreateCanister");

        let ?inst = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package"); // better message
        };
        let module2 = Common.unshareModule(module_); // TODO: necessary? or unshare only callbacks?
        switch (module2.callbacks.get(#CanisterCreated)) {
            case (?callbackName) {
                getIndirectCaller().callAllOneWay([{
                    canister;
                    name = callbackName;
                    data = to_candid({ // TODO
                        installationId;
                        moduleName;
                        canister;
                        user;
                    }); 
                }]);
            };
            case null {};
        };
        switch (moduleName) {
            case (?moduleName) {
                assert not Option.isSome(inst.modulesWithoutCode.get(moduleName)); // FIXME: on repeating interrupted installation?
                inst.modulesWithoutCode.put(moduleName, canister);
            };
            case null {
                // FIXME
            };
        };
        // TODO: `inst.modulesWithoutCode.size()` or need to prevent races `inst.modulesWithoutCode.size() + inst.installedModules.size()`?
        if (inst.modulesWithoutCode.size() + inst.installedModules.size() == inst.numberOfModulesToInstall) { // All cansters have been created. // TODO: efficient?
            switch (module2.callbacks.get(#AllCanistersCreated)) {
                case (?callbackName) {
                    getIndirectCaller().callAllOneWay([{ // FIXME: which indirect_caller I use?
                        canister;
                        name = callbackName;
                        data = to_candid({ // TODO
                            installationId;
                            moduleName;
                            canister;
                            user;
                        });
                    }]);
                };
                case null {};
            };
        };
    };

    /// Internal
    public shared({caller}) func onInstallCode({
        installationId: Common.InstallationId;
        canister: Principal;
        moduleName: ?Text;
        user: Principal;
        module_: Common.SharedModule;
    }): async () {
        onlyOwner(caller, "onInstallCode");

        let ?inst = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package"); // better message
        };
        let module2 = Common.unshareModule(module_); // TODO: necessary?
        // TODO: first `#CodeInstalled` or first `_registerNamedModule`?
        switch (module2.callbacks.get(#CodeInstalled)) {
            case (?callbackName) {
                getIndirectCaller().callAllOneWay([{ // FIXME: this indirect caller?
                    canister;
                    name = callbackName;
                    data = to_candid(); // TODO 
                }]);
            };
            case null {};
        };
        switch (moduleName) {
            case (?moduleName) {
                // FIXME: on repeating interrupted installation?
                assert Option.isSome(inst.modulesWithoutCode.get(moduleName)); // FIXME: on repeating interrupted installation?
                assert not Option.isSome(inst.installedModules.get(moduleName)); // FIXME: It fails for an unknown reason
                inst.modulesWithoutCode.delete(moduleName);
                inst.installedModules.put(moduleName, canister); // FIXME: What's about unnamed modules?
            };
            case null {
                // FIXME
            };
        };
        if (inst.installedModules.size() == inst.numberOfModulesToInstall) { // All module have been installed. // TODO: efficient?
            // TODO: order of this code
            _updateAfterInstall({installationId});
            switch (inst.whatToInstall) {
                case (#simplyModules _) {
                    let ?inst2 = installedPackages.get(installationId) else {
                        Debug.trap("no such installationId: " # debug_show(installationId));
                    };
                    inst2.allModules.add(canister);
                    switch (moduleName) {
                        case (?moduleName) {
                            inst2.allModules.add(canister);
                            inst2.modules.put(moduleName, canister);
                        };
                        case null {};
                    };
                };
                case (#package) {
                    // Package modules are updated after installation of all modules.
                    // TODO: Do it here instead.
                }
            };
            halfInstalledPackages.delete(installationId);
            switch (module2.callbacks.get(#CodeInstalledForAllCanisters)) {
                case (?callbackName) {
                    getIndirectCaller().callAllOneWay([{ // FIXME: this indirect caller?
                        canister;
                        name = callbackName;
                        data = to_candid({ // TODO
                            installationId;
                            moduleName;
                            canister;
                            user;
                        });
                    }]);
                };
                case null {
                };
            };
        };
    };

    // TODO: Keep registry of ALL installed modules.
    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        switch (ourHalfInstalled.whatToInstall) {
            case (#package _) {
                installedPackages.put(installationId, {
                    id = installationId;
                    name = ourHalfInstalled.packageName;
                    package = ourHalfInstalled.package;
                    version = ourHalfInstalled.package.base.version; // TODO: needed?
                    // FIXME: Need deep copy for `modules`?
                    modules = ourHalfInstalled.installedModules;
                    packageRepoCanister = ourHalfInstalled.packageRepoCanister;
                    allModules = Buffer.Buffer<Principal>(0);
                });
                switch (installedPackagesByName.get(ourHalfInstalled.package.base.name)) {
                    case (?ids) {
                        installedPackagesByName.put(ourHalfInstalled.package.base.name, Array.append(ids, [installationId]));
                    };
                    case null {
                        installedPackagesByName.put(ourHalfInstalled.package.base.name, [installationId]);
                    };
                };
            };
            case (#simplyModules _) {};
        };
    };

    // TODO: Uncomment.
    // public shared({caller}) func uninstallPackage(installationId: Common.InstallationId)
    //     : async ()
    // {
    //     onlyOwner(caller, "uninstallPackage");

    //     let ?installation = installedPackages.get(installationId) else {
    //         Debug.trap("no such installed installation");
    //     };
    //     let part: RepositoryPartition.RepositoryPartition = actor (Principal.toText(installation.packageRepoCanister));
    //     let packageInfo = await part.getPackage(installation.name, installation.version);

    //     let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
    //         numberOfModulesToInstall = installation.modules.size(); // TODO: Is it a nonsense?
    //         name = installation.name;
    //         version = installation.version;
    //         // FIXME: Is `modules` expression correct?
    //         modules = HashMap.fromIter<Text, (Principal, {#empty; #installed})>( // TODO: can be made simpler?
    //             Iter.map<(Text, Principal), (Text, (Principal, {#empty; #installed}))>(
    //                 installation.modules.entries(),
    //                 func ((x, y): (Text, Principal)): (Text, (Principal, {#empty; #installed})) = (x, (y, #installed)),
    //             ),
    //             installation.modules.size(),
    //             Text.equal,
    //             Text.hash,
    //         );
    //         package = packageInfo;
    //         packageRepoCanister = installation.packageRepoCanister;
    //         preinstalledModules = null; // TODO: Seems right, but check again.
    //     };
    //     halfInstalledPackages.put(installationId, ourHalfInstalled);

    //     // TODO:
    //     // let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
    //     // let installation = await part.getPackage(packageName, version);
    //     let #real realPackage = packageInfo.specific else {
    //         Debug.trap("trying to directly install a virtual installation");
    //     };

    //     await* _finishUninstallPackage({
    //         installationId;
    //         ourHalfInstalled;
    //         realPackage;
    //     });
    // };

    // TODO: Uncomment.
    // private func _finishUninstallPackage({
    //     installationId: Nat;
    //     ourHalfInstalled: Common.HalfInstalledPackageInfo;
    //     realPackage: Common.RealPackageInfo;
    // }): async* () {
    //     let IC: CanisterDeletor = actor("aaaaa-aa");
    //     while (/*ourHalfInstalled.modules.size()*/0 != 0) { // FIXME
    //         let vals = []; //Iter.toArray(ourHalfInstalled.modules.vals()); // TODO: slow // FIXME
    //         let canister_id = vals[vals.size() - 1].0;
    //         getIndirectCaller().callAllOneWay([
    //             {
    //                 canister = Principal.fromActor(IC);
    //                 name = "stop_canister";
    //                 data = to_candid({canister_id});
    //             },
    //             {
    //                 canister = Principal.fromActor(IC);
    //                 name = "delete_canister";
    //                 data = to_candid({canister_id});
    //             },
    //         ]);
    //         ignore ourHalfInstalled.modules.removeLast();
    //     };
    //     installedPackages.delete(installationId);
    //     let ?byName = installedPackagesByName.get(ourHalfInstalled.name) else {
    //         Debug.trap("programming error: can't get package by name");
    //     };
    //     // TODO: The below is inefficient and silly, need to change data structure?
    //     if (Array.size(byName) == 1) {
    //         installedPackagesByName.delete(ourHalfInstalled.name);
    //     } else {
    //         let new = Iter.filter(byName.vals(), func (e: Common.InstallationId): Bool {
    //             e != installationId;
    //         });
    //         installedPackagesByName.put(ourHalfInstalled.name, Iter.toArray(new));
    //     };
    //     halfInstalledPackages.delete(installationId);
    // };

    // FIXME: Uncomment:
    // public shared({caller}) func finishInstallPackage({
    //     installationId: Nat;
    // }): async () {
    //     onlyOwner(caller, "finishInstallPackage");
        
    //     let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
    //         Debug.trap("package installation has not been started");
    //     };
    //     let #real realPackage = ourHalfInstalled.package.specific else {
    //         Debug.trap("trying to directly install a virtual package");
    //     };
    //     await* _finishInstallPackage({
    //         installationId;
    //         ourHalfInstalled;
    //        realPackage;
    //         caller;
    //     });
    // };

    // FIXME: Uncomment:
    // FIXME: Rewrite
    // private func _finishInstallPackage({
    //      installationId: Nat;
    //      ourHalfInstalled: Common.HalfInstalledPackageInfo;
    //      realPackage: Common.RealPackageInfo;
    //      caller: Principal; // TODO: Rename to `user`.
    //  }): async* () {
    //     label install for ((moduleName, wasmModule) in realPackage.modules.vals()) {
    //         let ?state = ourHalfInstalled.modules.get(moduleName) else {
    //             Debug.trap("_finishInstallPackage: programming error");
    //         };
    //         if (state.1 == #installed) {
    //             continue install;
    //         };
    //         let installArg = to_candid({
    //             arg = to_candid({}); // TODO: correct?
    //         });
    //         if (Option.isNull(ourHalfInstalled.preinstalledModules)) {
    //             // FIXME: `canister` is `()`.
    //             let canister = await* _installModule(wasmModule, to_candid(()), ?installArg, getIndirectCaller(), Principal.fromActor(this), installationId, installedPackages, caller);
    //         }/* else {
    //             // We don't need to initialize installed module, because it can be only
    //             // PM's frontend.
    //         }*/;
    //     };

    //     _updateAfterInstall({installationId});
    // };

    //  /// Finish uninstallation of a half-installed package.
    // public shared({caller}) func finishUninstallPackage({installationId: Nat}): async () {
    //     onlyOwner(caller, "finishUninstallPackage");
        
    //     let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
    //         Debug.trap("package uninstallation has not been started");
    //     };
    //     let #real realPackage = ourHalfInstalled.package.specific else {
    //         Debug.trap("trying to directly install a virtual package");
    //     };
    //     await* _finishUninstallPackage({
    //         installationId;
    //         ourHalfInstalled;
    //         realPackage;
    //     });
    // };

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
        //         numberOfModulesToInstall: Nat;
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
            Common.IntHash,
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
        packageRepoCanister: Principal;
        name: Common.PackageName;
        version: Common.Version;
    }] {
        Iter.toArray(Iter.map<(Common.InstallationId, Common.HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            packageRepoCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        }>(halfInstalledPackages.entries(), func (x: (Common.InstallationId, Common.HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            packageRepoCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        } =
            {
                installationId = x.0;
                packageRepoCanister = x.1.packageRepoCanister;
                name = x.1.packageName;
                version = x.1.package.base.version;
            },
        ));
    };

    /// TODO: very unstable API.
    public query func getHalfInstalledPackageModulesById(installationId: Common.InstallationId): async [(Text, Principal)] {
        let ?res = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        Iter.toArray(res.installedModules.entries());
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
}