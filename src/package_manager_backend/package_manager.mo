/// TODO: Methods to query for all installed packages.
import Option "mo:base/Option";
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
import Error "mo:base/Error";
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import IndirectCaller "indirect_caller";
import SimpleIndirect "simple_indirect";

shared({caller = initialCaller}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    initialIndirect: Principal; // TODO: Rename.
    simpleIndirect: Principal;
    user: Principal;
    // installationId: Common.InstallationId;
    // userArg: Blob;
}) = this {
    // let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    stable var initialized = false;

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (initialIndirect, ()),
                (simpleIndirect, ()), // TODO: superfluous?
                (user, ()),
            ].vals(), // TODO: Are all required?
            4,
            Principal.equal,
            Principal.hash);

    public shared({caller}) func init({
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManagerOrBootstrapper: Principal;
    }): async () {
        onlyOwner(caller, "init");

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installPackage`. // TODO: needed?

        // ourPM := actor (Principal.toText(packageManagerOrBootstrapper)): OurPMType;
        initialized := true;
    };

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
        if (not initialized) {
            Debug.trap("package_manager: not initialized");
        };
        // TODO: need b44c4a9beec74e1c8a7acbe46256f92f_isInitialized() method in this canister, too? Maybe, remove the prefix?
        let a = getIndirectCaller().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
        let b = getSimpleIndirect().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
        // FIXME: https://github.com/dfinity/motoko/issues/4837
        // let c = do {
        //     let ?pkg = installedPackages.get(installationId) else {
        //         Debug.trap("package manager is not yet installed");
        //     };
        //     let ?frontend = pkg.modules.get("frontend") else {
        //         Debug.trap("programming error 1");
        //     };
        //     let f: Asset.AssetCanister = actor(Principal.toText(frontend));
        //     f.get({key = "/index.html"; accept_encodings = ["gzip"]});
        // };
        ignore {{a0 = await a; b0 = await b/*; c0 = await c*/}}; // run in parallel
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

    stable var _installedPackagesByNameSave: [(Blob, {
        all: [Common.InstallationId];
        default: Common.InstallationId;
    })] = [];
    var installedPackagesByName: HashMap.HashMap<Blob, {
        all: Buffer.Buffer<Common.InstallationId>;
        var default: Common.InstallationId;
    }> =
        HashMap.HashMap(0, Blob.equal, Blob.hash);

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

    // TODO: Copy this code to other modules:
    func onlyOwner(caller: Principal, msg: Text) {
        if (Option.isNull(owners.get(caller))) {
            Debug.trap(debug_show(caller) # " is not the owner: " # msg);
        };
    };

    public shared({caller}) func installPackage({ // TODO: Rename.
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryPartitionRO;
        }];
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async {minInstallationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackage");

        let minInstallationId = nextInstallationId;
        nextInstallationId += packages.size();

        await* _installModulesGroup({
            indirectCaller = getIndirectCaller();
            whatToInstall = #package;
            minInstallationId;
            packages = Iter.toArray(Iter.map<
                {
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryPartitionRO;
                },
                {
                    repo: Common.RepositoryPartitionRO;
                    packageName: Common.PackageName;
                    version: Common.Version;
                    preinstalledModules: [(Text, Principal)];
                }
            >(packages.vals(), func (p: {
                repo: Common.RepositoryPartitionRO;
                packageName: Common.PackageName;
                version: Common.Version;
            }) = {
                repo = p.repo;
                packageName = p.packageName;
                version = p.version;
                preinstalledModules = [];
            }));
            installPackage = true;
            pmPrincipal = Principal.fromActor(this);
            // objectToInstall = #package {packageName; version}; // TODO
            user;
            afterInstallCallback;
        });
    };

    /// Internal. Install packages after bootstrapping IC Pack.
    public shared({caller}) func bootstrapAdditionalPackages(
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryPartitionRO;
        }],
        user: Principal,
        minInstallationId: Common.InstallationId, // TODO: Remove.
    ) {
        try {
            onlyOwner(caller, "bootstrapAdditionalPackages");

            ignore await this.installPackage({ // TODO: no need for shared call
                packages;
                user;
                afterInstallCallback = null;
            });
        }
        catch(e) {
            Debug.print(Error.message(e));
        }
    };

    /// Internal used for bootstrapping.
    public shared({caller}) func installPackageWithPreinstalledModules({
        whatToInstall: {
            #package;
            // #simplyModules : [(Text, Common.SharedModule)]; // TODO
        };
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryPartitionRO; 
        user: Principal;
        indirectCaller: Principal;
        /// Additional packages to install after bootstrapping.
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryPartitionRO;
        }];
        preinstalledModules: [(Text, Principal)];
    })
        : async {minInstallationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackageWithPreinstalledModules");

        let minInstallationId = nextInstallationId;
        nextInstallationId += additionalPackages.size();

        Debug.print("B1"); // FIXME: Remove.
        // We first fully install the package manager, and only then other packages.
        await* _installModulesGroup({
            indirectCaller = actor(Principal.toText(indirectCaller));
            whatToInstall;
            minInstallationId; // FIXME: Move inside packages.
            packages = [{packageName; version; repo; preinstalledModules}]; // HACK
            installPackage = true; // TODO
            pmPrincipal = Principal.fromActor(this);
            // objectToInstall = #package {packageName; version}; // TODO
            user;
            afterInstallCallback = ?{
                canister = Principal.fromActor(this);
                name = "bootstrapAdditionalPackages";
                data = to_candid(additionalPackages, user, minInstallationId);
            };
        });
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-realiability, it installed partially.
    ///
    /// FIXME: It reuses an existing `installationId`.
    // public shared({caller}) func installNamedModules({
    //     installationId: Common.InstallationId;
    //     repo: Common.RepositoryPartitionRO; // TODO: Install from multiple repos.
    //     modules: [(Text, Common.SharedModule)]; // TODO: installArg, initArg
    //     _avoidRepeated: Bool; // TODO: Use.
    //     user: Principal;
    //     preinstalledModules: [(Text, Principal)];
    // }): async {installationId: Common.InstallationId} {
    //     onlyOwner(caller, "installNamedModule");

    //     let ?inst = installedPackages.get(installationId) else {
    //         Debug.trap("no such package");
    //     };
    //     await* _installModulesGroup({
    //         indirectCaller = getIndirectCaller();
    //         whatToInstall = #simplyModules modules;
    //         installationId;
    //         packageName = inst.package.base.name;
    //         packageVersion = inst.package.base.version;
    //         pmPrincipal = Principal.fromActor(this);
    //         repo;
    //         objectToInstall = #package {packageName = inst.package.base.name; version = inst.package.base.version}; // TODO
    //         user;
    //         preinstalledModules;
    //     });
    // };

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

    /// Internal.
    ///
    /// Initialize installation process object.
    public shared({caller}) func installStart({
        whatToInstall: {
            #package;
            // #simplyModules : [(Text, Common.SharedModule)]; // TODO
        };
        minInstallationId: Common.InstallationId; // FIXME: Move inside packages array.
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        user: Principal;
        packages: [{
            package: Common.SharedPackageInfo;
            repo: Common.RepositoryPartitionRO;
            preinstalledModules: [(Text, Principal)];
        }];
    }) {
        Debug.print("E1");
        onlyOwner(caller, "installStart");
        Debug.print("E2");

        for (p0 in packages.keys()) {
            let p = packages[p0];
            let #real realPackage = p.package.specific else {
                Debug.trap("trying to directly install a virtual package");
            };

            let package2 = Common.unsharePackageInfo(p.package); // TODO: why used twice below? seems to be a mis-programming.
            let numModules = realPackage.modules.size();

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
                // case (#simplyModules ms) { // TODO
                //     let iter = Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                //         ms.vals(),
                //         func ((k, v): (Text, Common.SharedModule)): (Text, Common.Module) = (k, Common.unshareModule(v)),
                //     );
                //     (iter, ms.size()); // TODO: efficient?
                // };
            };
            let realModulesToInstall2 = Iter.toArray(realModulesToInstall); // Iter to be used two times, convert to array.

            let preinstalledModules2 = HashMap.fromIter<Text, Principal>(
                p.preinstalledModules.vals(), p.preinstalledModules.size(), Text.equal, Text.hash);
            let arrayOfEmpty = Array.tabulate(realModulesToInstallSize, func (_: Nat): ?(?Text, Principal) = null);

            Debug.print("E3");
            let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
                numberOfModulesToInstall = numModules;
                // id = installationId;
                packageName = p.package.base.name;
                version = p.package.base.version;
                modules = OrderedHashMap.OrderedHashMap<Text, (Principal, {#empty; #installed})>(numModules, Text.equal, Text.hash);
                // packageDescriptionIn = part;
                package = package2;
                packageRepoCanister = Principal.fromActor(p.repo);
                preinstalledModules = preinstalledModules2;
                modulesToInstall = HashMap.fromIter<Text, Common.Module>(
                    realModulesToInstall2.vals(),
                    realModulesToInstallSize,
                    Text.equal,
                    Text.hash);
                modulesWithoutCode = Buffer.fromArray(arrayOfEmpty);
                installedModules = Buffer.fromArray(arrayOfEmpty);
                whatToInstall;
                minInstallationId;
                afterInstallCallback;
                var alreadyCalledAllCanistersCreated = false;
                var totalNumberOfModulesRemainingToInstall = numModules;
            };
            halfInstalledPackages.put(minInstallationId + p0, ourHalfInstalled);

            Debug.print("E4");
            await* doInstallFinish();
        };
    };

    // FIXME: Can other packages be installed if one of them fails?
    private func doInstallFinish(): async* () {
        Debug.print("F1");
        for ((p0, pkg) in halfInstalledPackages.entries()) {
            let p = pkg.package;
            let modules: Iter.Iter<(Text, Common.Module)> = switch (#package/*whatToInstall*/) {
                // case (#simplyModules m) {
                //     Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(
                //         m.vals(),
                //         func (p: (Text, Common.SharedModule)) = (p.0, Common.unshareModule(p.1)),
                //     );
                // };
                case (#package) {
                    switch (p.specific) {
                        case (#real pkgReal) {
                            Iter.filter<(Text, Common.Module)>(
                                pkgReal.modules.entries(),
                                func (p: (Text, Common.Module)) = p.1.installByDefault,
                            );
                        };
                        case (#virtual _) [].vals();
                    };
                }
            };

            let bi = if (pkg.preinstalledModules.size() == 0) { // TODO: All this block is a crude hack.
                [("backend", Principal.fromActor(this)), ("indirect", Principal.fromActor(this)), ("simple_indirect", Principal.fromActor(getSimpleIndirect()))];
            } else {
                Iter.toArray(pkg.preinstalledModules.entries()); // TODO: inefficient?
            };
            let coreModules = HashMap.fromIter<Text, Principal>(bi.vals(), bi.size(), Text.equal, Text.hash);
            var moduleNumber = 0;
            let ?backend = coreModules.get("backend") else {
                Debug.trap("error 1");
            };
            let ?indirect = coreModules.get("indirect") else {
                Debug.trap("error 1");
            };
            let ?simple_indirect = coreModules.get("simple_indirect") else {
                Debug.trap("error 1");
            };
            // The following (typically) does not overflow cycles limit, because we use an one-way function.
            var i = 0;
            Debug.print("Z1: " # debug_show(pkg.afterInstallCallback));
            for ((name, m): (Text, Common.Module) in modules) {
                // Starting installation of all modules in parallel:
                getIndirectCaller().installModule({
                    installPackage = true/*whatToInstall == #package*/; // TODO: correct?
                    moduleNumber;
                    moduleName = ?name;
                    installArg = to_candid({
                        installationId = p0;
                        packageManagerOrBootstrapper = backend;
                    }); // TODO: Add more arguments.
                    installationId = p0;
                    packageManagerOrBootstrapper = backend;
                    initialIndirect = indirect;
                    simpleIndirect = simple_indirect;
                    preinstalledCanisterId = coreModules.get(name);
                    user; // TODO: `!`
                    wasmModule = Common.shareModule(m); // TODO: We unshared, then shared it, huh?
                    afterInstallCallback = pkg.afterInstallCallback;
                });
                // TODO: Do two following variables duplicate each other?
                moduleNumber += 1;
                i += 1;
            };
        };
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
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
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
        let #real realPackage = inst.package.specific else { // TODO: fails with virtual packages
            Debug.trap("trying to directly install a virtual installation");
        };
        let inst3: HashMap.HashMap<Text, Principal> = HashMap.HashMap(inst.installedModules.size(), Text.equal, Text.hash);
        // Keep the below code in-sync with `totalNumberOfModulesRemainingToInstall` variable value!
        // TODO: The below code is a trick.
        // Note that we have different algorithms for zero and non-zero number of callbacks.
        // let #real package = inst.package.specific else { // TODO: virtual packages
        //     Debug.trap("virtual packages not yet supported");
        // };
        inst.totalNumberOfModulesRemainingToInstall -= 1;
        if (inst.totalNumberOfModulesRemainingToInstall == 0) { // All module have been installed.
            // TODO: order of this code
            _updateAfterInstall({installationId});
            let ?inst2 = installedPackages.get(installationId) else {
                Debug.trap("no such installationId: " # debug_show(installationId));
            };
            switch (inst.whatToInstall) {
                case (#simplyModules _) {
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
            // if (inst.totalNumberOfModulesRemainingToInstall == 0) { // FIXME: Edge case of package with no modules.
            //     switch (afterInstallCallback) {
            //         case (?afterInstallCallback) {
            //             ignore getSimpleIndirect().callAllOneWay([afterInstallCallback]);
            //         };
            //         case null {};
            //     };
            // };
            for (m in inst.installedModules.vals()) {
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
                            Debug.trap("programming error 3");
                        };
                        ignore getSimpleIndirect().callAllOneWay([{
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
                    case (null) {};
                };
            };
            switch (afterInstallCallback) {
                case (?afterInstallCallback) {
                    ignore getSimpleIndirect().callAllOneWay([afterInstallCallback]);
                };
                case null {};
            };
            halfInstalledPackages.delete(installationId);
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
                                    Debug.trap("programming error 4");
                                };
                                let ?n = s.0 else {
                                    Debug.trap("programming error 5");
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
                    var pinned = false;
                });
                let guid2 = Common.amendedGUID(ourHalfInstalled.package.base.guid, ourHalfInstalled.package.base.name);
                switch (installedPackagesByName.get(guid2)) {
                    case (?old) {
                        old.all.add(installationId);
                    };
                    case null {
                        installedPackagesByName.put(guid2, {
                            all = Buffer.fromArray([installationId]);
                            var default = installationId;
                        });
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

        _installedPackagesByNameSave := Iter.toArray/*<{all: [Common.InstallationId]; default: Common.InstallationId}>*/(
            Iter.map<
                (Blob, {all: Buffer.Buffer<Common.InstallationId>; var default: Common.InstallationId}),
                (Blob, {all: [Common.InstallationId]; default: Common.InstallationId})
            >(
                installedPackagesByName.entries(),
                func ((name, x): (Blob, {all: Buffer.Buffer<Common.InstallationId>; var default: Common.InstallationId})) =
                    (name, {all = Buffer.toArray(x.all); default = x.default}),
            ),
        );

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
            Iter.map<
                (Blob, {all: [Common.InstallationId]; default: Common.InstallationId}),
                (Blob, {all: Buffer.Buffer<Common.InstallationId>; var default: Common.InstallationId})
            >(
                _installedPackagesByNameSave.vals(),
                func ((name, x): (Blob, {all: [Common.InstallationId]; default: Common.InstallationId})) =
                    (name, {all = Buffer.fromArray(x.all); var default = x.default}),
            ),
            Array.size(_installedPackagesByNameSave),
            Blob.equal,
            Blob.hash,
        );
        _installedPackagesByNameSave := []; // Free memory.

        // halfInstalledPackages := TODO;
        _halfInstalledPackagesSave := []; // Free memory.
    };

    // Accessor method //

    public query({caller}) func getInstalledPackage(id: Common.InstallationId): async Common.SharedInstalledPackageInfo {
        onlyOwner(caller, "getInstalledPackage");

        let ?result = installedPackages.get(id) else {
            Debug.trap("no such installed package");
        };
        Common.installedPackageInfoShare(result);
    };

    /// TODO: very unstable API.
    /// FIXME
    public query({caller}) func getInstalledPackagesInfoByName(name: Text, guid: Blob)
        : async {all: [Common.SharedInstalledPackageInfo]; default: Common.InstallationId}
    {
        onlyOwner(caller, "getInstalledPackagesInfoByName");

        let guid2 = Common.amendedGUID(guid, name);
        let ?data = installedPackagesByName.get(guid2) else {
            return {all = []; default = 0};
        };
        // TODO: Eliminiate duplicate code:
        let all = Iter.toArray(Iter.map(data.all.vals(), func (id: Common.InstallationId): Common.SharedInstalledPackageInfo {
            let ?info = installedPackages.get(id) else {
                Debug.trap("getInstalledPackagesInfoByName: programming error");
            };
            Common.installedPackageInfoShare(info);
        }));
        {all = all; default = data.default}; // FIXME: Should preserve the default setting if previously installed this package.
    };

    /// TODO: very unstable API.
    public query({caller}) func getAllInstalledPackages(): async [(Common.InstallationId, Common.SharedInstalledPackageInfo)] {
        onlyOwner(caller, "getAllInstalledPackages");

        Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(
                installedPackages.entries(),
                func (info: (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) =
                    (info.0, Common.installedPackageInfoShare(info.1))
            )
        );
    };

    /// TODO: very unstable API.
    public query({caller}) func getHalfInstalledPackages(): async [{
        installationId: Common.InstallationId;
        packageRepoCanister: Principal;
        name: Common.PackageName;
        version: Common.Version;
    }] {
        onlyOwner(caller, "getHalfInstalledPackages");

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
    public query({caller}) func getHalfInstalledPackageModulesById(installationId: Common.InstallationId): async [(?Text, Principal)] {
        onlyOwner(caller, "getHalfInstalledPackageModulesById");

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
                        Debug.trap("programming error 6");
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
            // #simplyModules : [(Text, Common.SharedModule)]; // TODO
        };
        minInstallationId: Common.InstallationId;
        packages: [{
            repo: Common.RepositoryPartitionRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
        }];
        pmPrincipal: Principal;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async* {minInstallationId: Common.InstallationId}
    {
        Debug.print("C1"); // FIXME: Remove.
        indirectCaller.installPackageWrapper({
            whatToInstall;
            minInstallationId;
            packages;
            pmPrincipal;
            user;
            afterInstallCallback;
        });

        {minInstallationId};
    };

    public shared func setPinned(installationId: Common.InstallationId, pinned: Bool): async () {
        onlyOwner(Principal.fromActor(this), "setPinned");

        let ?inst = installedPackages.get(installationId) else {
            Debug.trap("no such installed package");
        };
        inst.pinned := pinned;
    };

    // TODO: Copy package specs to "userspace", in order to have `extraModules` fixed for further use.

    // Adjustable values //

    // TODO: a way to set.

    stable var newCanisterCycles = 400_000_000_000; // 4 times more, than creating a canister

    public query({caller}) func getNewCanisterCycles(): async Nat {
        onlyOwner(caller, "getNewCanisterCycles");

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

    public query({caller}) func getRepositories(): async [{canister: Principal; name: Text}] {
        onlyOwner(caller, "getRepositories");

        repositories;
    };

    public shared({caller}) func setDefaultInstalledPackage(name: Common.PackageName, guid: Blob, installationId: Common.InstallationId): async () {
        onlyOwner(caller, "setDefaultPackage");

        let guid2 = Common.amendedGUID(guid, name);
        let ?data = installedPackagesByName.get(guid2) else {
            Debug.trap("no such package");
        };
        data.default := installationId;
    };
}