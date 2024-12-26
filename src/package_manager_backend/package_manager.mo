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
import SimpleIndirect "simple_indirect";

shared({caller = initialCaller}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    initialIndirect: Principal; // TODO: Rename.
    simpleIndirect: Principal;
    user: Principal;
    // installationId: Common.InstallationId; // TODO: superfluous
    // userArg: Blob;
}) = this {
    // let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    // stable var initialized = false;

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (initialIndirect, ()),
                (user, ()),
            ].vals(), // TODO: Are all required?
            4,
            Principal.equal,
            Principal.hash);

    // public shared({caller}) func init(p: {
    //     // installationId: Common.InstallationId;
    //     // canister: Principal;
    //     // user: Principal;
    //     // packageManagerOrBootstrapper: Principal;
    // }) {
    //     onlyOwner(caller, "init");

    //     initialized := true;
    // };

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

    public composite query func isAllInitialized(): async () {
        // if (not initialized) {
        //     Debug.trap("package_manager: not initialized");
        // };
        // TODO: need b44c4a9beec74e1c8a7acbe46256f92f_isInitialized() method in this canister, too? Maybe, remove the prefix?
        let a = getIndirectCaller().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
        let b = getSimpleIndirect().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
        ignore [await a, await b]; // run in parallel
        // FIXME: Also check frontend.
    };

    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = ?actor(Principal.toText(initialIndirect)); // TODO: Remove `?`.
    stable var simple_indirect_: ?SimpleIndirect.SimpleIndirect = ?actor(Principal.toText(simpleIndirect)); // TODO: Remove `?`.

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller_2 = indirect_caller_ else {
            Debug.trap("indirect_caller_ not initialized");
        };
        indirect_caller_2;
    };

    private func getSimpleIndirect(): SimpleIndirect.SimpleIndirect {
        let ?simple_indirect_2 = simple_indirect_ else {
            Debug.trap("simple_indirect_ not initialized");
        };
        simple_indirect_2;
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

        await* _installModulesGroup({
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

        await* _installModulesGroup({
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
        await* _installModulesGroup({
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
        });
    };

    type ObjectToInstall = {
        #package : {
            packageName: Common.PackageName;
            version: Common.Version;
        };
        #namedModules : {
            dest: Common.InstallationId;
            modules: [(Text, Blob, ?Blob)]; // name, installArg, initArg // TODO: Use named fields.
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
                let iter = Iter.filter<(Text, Common.Module)>(
                    package3.modules.entries(),
                    func ((_k, m): (Text, Common.Module)): Bool = m.installByDefault,
                );
                (iter, package3.modules.size()); // TODO: efficient?
            };
            case (#simplyModules ms) {
                let iter = Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                    ms.vals(),
                    func ((k, v): (Text, Common.SharedModule)): (Text, Common.Module) = (k, Common.unshareModule(v)),
                );
                (iter, ms.size()); // TODO: efficient?
            };
        };
        let realModulesToInstall2 = Iter.toArray(realModulesToInstall); // Iter to be used two times, convert to array.

        let preinstalledModules2 = HashMap.fromIter<Text, Principal>(
            preinstalledModules.vals(), preinstalledModules.size(), Text.equal, Text.hash);
        let arrayOfEmpty = Array.tabulate(realModulesToInstallSize, func (_: Nat): ?(?Text, Principal) = null);
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
            modulesWithoutCode = Buffer.fromArray(arrayOfEmpty);
            installedModules = Buffer.fromArray(arrayOfEmpty);
            whatToInstall;
            var alreadyCalledAllCanistersCreated = false;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);
    };

    /// Internal
    public shared({caller}) func onInstallCode({
        installationId: Common.InstallationId;
        canister: Principal;
        moduleNumber: Nat;
        moduleName: ?Text;
        user: Principal;
        module_: Common.SharedModule;
        packageManagerOrBootstrapper: Principal;
    }): async () {
        // TODO: Move after `onlyOwner` call:
        Debug.print("Called onInstallCode for canister " # debug_show(canister) # " (" # debug_show(moduleName) # ")");

        onlyOwner(caller, "onInstallCode");

        let ?inst = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package"); // better message
        };
        assert Option.isSome(inst.modulesWithoutCode.get(moduleNumber));
        assert Option.isNull(inst.installedModules.get(moduleNumber));
        inst.modulesWithoutCode.put(moduleNumber, null);
        inst.installedModules.put(moduleNumber, ?(moduleName, canister));
        if (Buffer.forAll(inst.installedModules, func (x: ?(?Text, Principal)): Bool = x != null)) { // All module have been installed. // TODO: efficient?
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
            let ?pkg = halfInstalledPackages.get(installationId) else {
                Debug.trap("PackageManager: programming error");
            };
            halfInstalledPackages.delete(installationId);
            let #real realPackage = pkg.package.specific else { // TODO: fails with virtual packages
                Debug.trap("trying to directly install a virtual installation");
            };
            let inst3: HashMap.HashMap<Text, Principal> = HashMap.HashMap(pkg.installedModules.size(), Text.equal, Text.hash);
            for (m in pkg.installedModules.vals()) {
                switch (m) {
                    case (?(?n, p)) {
                        inst3.put(n, p);
                    };
                    case _ {};
                };
            };
            for ((moduleName2, module4) in realPackage.modules.entries()) {
                switch (module4.callbacks.get(#CodeInstalledForAllCanisters)) {
                    case (?callbackName) {
                        let ?cbPrincipal = inst3.get(moduleName2) else {
                            Debug.trap("programming error");
                        };
                        // let indirect: IndirectCaller.IndirectCaller = switch (indirect_caller_) { // hack
                        //     case (?v) v;
                        //     case null {
                        //         Debug.trap("programming error");
                        //     };
                        // };
                        let simpleIndirect: SimpleIndirect.SimpleIndirect = switch (simple_indirect_) { // hack
                            case (?v) v;
                            case null {
                                Debug.trap("programming error");
                            };
                        };
                        Debug.print("GOING CALL(" # debug_show(Principal.fromActor(simpleIndirect)) # "): " # debug_show(cbPrincipal) # "/" # callbackName.method); // FIXME: Remove.
                        await simpleIndirect.callAllOneWay([{
                            canister = cbPrincipal;
                            name = callbackName.method;
                            data = to_candid({ // TODO
                                installationId;
                                canister;
                                user;
                                packageManagerOrBootstrapper; // TODO: Remove?
                                module_;
                            });
                        }]);
                    };
                    case null {};
                };
            };
        };
    };

    // TODO: probably superfluous
    public shared({caller}) func onCreateCanister({
        installationId: Common.InstallationId;
        moduleNumber: Nat;
        moduleName: ?Text;
        canister: Principal;
        user: Principal;
    }): async () {
        // TODO: Move after `onlyOwner` call:
        Debug.print("Called onCreateCanister for canister " # debug_show(canister) # " (" # debug_show(moduleName) # ")");

        onlyOwner(caller, "onCreateCanister");

        let ?inst = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package"); // better message
        };
        if (not inst.alreadyCalledAllCanistersCreated) {
            assert Option.isNull(inst.modulesWithoutCode.get(moduleNumber));
            inst.modulesWithoutCode.put(moduleNumber, ?(moduleName, canister)); // TODO: duplicate with below
            var missingCanister = false; // There is a module for which canister wasn't created yet.
            assert(inst.modulesWithoutCode.size() == inst.installedModules.size());
            var i = 0;
            label searchMissing while (i != inst.modulesWithoutCode.size()) { // TODO: efficient?
                if (Option.isSome(inst.modulesWithoutCode.get(i)) or Option.isSome(inst.installedModules.get(i))) {
                    missingCanister := true;
                    break searchMissing;
                };
                i += 1;
            };
            inst.alreadyCalledAllCanistersCreated := true;
        };
        inst.modulesWithoutCode.put(moduleNumber, ?(moduleName, canister)); // TODO: duplicate with above
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
                    modules = HashMap.fromIter(
                        Iter.map<?(?Text, Principal), (Text, Principal)>(
                            ourHalfInstalled.installedModules.vals(),
                            func (x: ?(?Text, Principal)) {
                                let ?s = x else {
                                    Debug.trap("programming error");
                                };
                                let ?n = s.0 else {
                                    Debug.trap("programming error");
                                };
                                (n, s.1);
                            }
                        ),
                        ourHalfInstalled.installedModules.size(),
                        Text.equal,
                        Text.hash,
                    );
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
    //     while (/*ourHalfInstalled.modules.size()*/0 != 0) {
    //         let vals = []; //Iter.toArray(ourHalfInstalled.modules.vals());
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
    public query func getHalfInstalledPackageModulesById(installationId: Common.InstallationId): async [(?Text, Principal)] {
        let ?res = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        // TODO: May be a little bit slow.
        Iter.toArray(
            Iter.map<?(?Text, Principal), (?Text, Principal)>(
                Iter.filter<?(?Text, Principal)>(
                    res.installedModules.vals(),
                    func (x: ?(?Text, Principal)): Bool {
                        Option.isSome(x);
                    },
                ),
                func (x: ?(?Text, Principal)): (?Text, Principal) {
                    let ?y = x else {
                        Debug.trap("programming error");
                    };
                    y;
                },
            ),
        );
    };

    private func _installModulesGroup({
        indirectCaller: IndirectCaller.IndirectCaller;
        whatToInstall: {
            #package;
            #simplyModules : [(Text, Common.SharedModule)];
        };
        installationId: Common.InstallationId;
        packageName: Common.PackageName;
        packageVersion: Common.Version;
        pmPrincipal: Principal;
        repo: Common.RepositoryPartitionRO;
        user: Principal;
        preinstalledModules: [(Text, Principal)];
    })
        : async* {installationId: Common.InstallationId}
    {
        indirectCaller.installPackageWrapper({
            whatToInstall;
            installationId;
            packageName;
            version = packageVersion;
            pmPrincipal;
            repo;
            user;
            preinstalledModules;
        });

        {installationId};
    };

    // TODO: Copy package specs to "userspace", in order to have `extraModules` fixed for further use.

    // Adjustable values //

    // TODO: a way to set.

    stable var newCanisterCycles = 400_000_000_000; // 4 times more, than creating a canister

    public query func getNewCanisterCycles(): async Nat {
        newCanisterCycles;
    };

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