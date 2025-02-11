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
import RBTree "mo:base/RBTree";
import Common "../common";
import IndirectCaller "indirect_caller";
import SimpleIndirect "simple_indirect";

shared({caller = initialCaller}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    indirectCaller: Principal; // TODO: Rename.
    simpleIndirect: Principal;
    user: Principal;
    // installationId: Common.InstallationId;
    // userArg: Blob;
}) = this {
    // let ?userArgValue: ?{ // TODO: Isn't this a too big "tower" of objects?
    // } = from_candid(userArg) else {
    //     Debug.trap("argument userArg is wrong");
    // };

    public type HalfInstalledPackageInfo = {
        modulesToInstall: HashMap.HashMap<Text, Common.Module>;
        packageRepoCanister: Principal; // TODO: needed? move to `#package`?
        whatToInstall: {
            #package;
            // #simplyModules : [(Text, SharedModule)]; // TODO
        };
        modulesWithoutCode: Buffer.Buffer<?(?Text, Principal)>;
        installedModules: Buffer.Buffer<?(?Text, Principal)>;
        package: Common.PackageInfo;
        preinstalledModules: HashMap.HashMap<Text, Principal>;
        minInstallationId: Nat; // hack 
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        var alreadyCalledAllCanistersCreated: Bool;
        var totalNumberOfModulesRemainingToInstall: Nat;
        bootstrapping: Bool;
    };

    public type SharedHalfInstalledPackageInfo = {
        modulesToInstall: [(Text, Common.SharedModule)];
        packageRepoCanister: Principal; // TODO: needed? move to `#package`?
        whatToInstall: {
            #package;
            // #simplyModules : [(Text, SharedModule)]; // TODO
        };
        modulesWithoutCode: [?(?Text, Principal)];
        installedModules: [?(?Text, Principal)];
        package: Common.SharedPackageInfo;
        preinstalledModules: [(Text, Principal)];
        minInstallationId: Nat; // hack 
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        alreadyCalledAllCanistersCreated: Bool;
        totalNumberOfModulesRemainingToInstall: Nat;
        bootstrapping: Bool;
    };

    private func shareHalfInstalledPackageInfo(x: HalfInstalledPackageInfo): SharedHalfInstalledPackageInfo = {
        modulesToInstall = Iter.toArray<(Text, Common.SharedModule)>(Iter.map<(Text, Common.Module), (Text, Common.SharedModule)>(
            x.modulesToInstall.entries(),
            func (elt: (Text, Common.Module)) = (elt.0, Common.shareModule(elt.1)),
        ));
        packageRepoCanister = x.packageRepoCanister;
        whatToInstall = x.whatToInstall;
        modulesWithoutCode = Buffer.toArray(x.modulesWithoutCode);
        installedModules = Buffer.toArray(x.installedModules);
        package = Common.sharePackageInfo(x.package);
        preinstalledModules = Iter.toArray(x.preinstalledModules.entries());
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        alreadyCalledAllCanistersCreated = x.alreadyCalledAllCanistersCreated;
        totalNumberOfModulesRemainingToInstall = x.totalNumberOfModulesRemainingToInstall;
        bootstrapping = x.bootstrapping;
    };

    private func unshareHalfInstalledPackageInfo(x: SharedHalfInstalledPackageInfo): HalfInstalledPackageInfo = {
        modulesToInstall = HashMap.fromIter(
            Iter.map<(Text, Common.SharedModule), (Text, Common.Module)>(x.modulesToInstall.vals(), func (elt: (Text, Common.SharedModule)) = (elt.0, Common.unshareModule(elt.1))),
            x.modulesToInstall.size(),
            Text.equal,
            Text.hash
        );
        packageRepoCanister = x.packageRepoCanister;
        whatToInstall = x.whatToInstall;
        modulesWithoutCode = Buffer.fromArray(x.modulesWithoutCode);
        installedModules = Buffer.fromArray(x.installedModules);
        package = Common.unsharePackageInfo(x.package);
        preinstalledModules = HashMap.fromIter(x.preinstalledModules.vals(), x.preinstalledModules.size(), Text.equal, Text.hash);
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        var alreadyCalledAllCanistersCreated = x.alreadyCalledAllCanistersCreated;
        var totalNumberOfModulesRemainingToInstall = x.totalNumberOfModulesRemainingToInstall;
        bootstrapping = x.bootstrapping;
    };

    public type HalfUninstalledPackageInfo = {
        installationId: Common.InstallationId;
        var remainingModules: Nat; // FIXME: It does not finish uninstallation, if some module was already uninstalled.
    };

    public type SharedHalfUninstalledPackageInfo = {
        installationId: Common.InstallationId;
        remainingModules: Nat;
    };

    private func shareHalfUninstalledPackageInfo(x: HalfUninstalledPackageInfo): SharedHalfUninstalledPackageInfo = {
        installationId = x.installationId;
        remainingModules = x.remainingModules;
    };

    private func unshareHalfUninstalledPackageInfo(x: SharedHalfUninstalledPackageInfo): HalfUninstalledPackageInfo = {
        installationId = x.installationId;
        var remainingModules = x.remainingModules;
    };

    public type HalfUpgradedPackageInfo = {
        var remainingModules: Nat;
    };

    public type SharedHalfUpgradedPackageInfo = {
        remainingModules: Nat;
    };

    private func shareHalfUpgradedPackageInfo(x: HalfUpgradedPackageInfo): SharedHalfUpgradedPackageInfo = {
        remainingModules = x.remainingModules;
    };

    private func unshareHalfUpgradedPackageInfo(x: SharedHalfUpgradedPackageInfo): HalfUpgradedPackageInfo = {
        var remainingModules = x.remainingModules;
    };

    stable var initialized = false;

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (indirectCaller, ()), // temporary
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

        owners.put(Principal.fromActor(this), ()); // self-usage to call `this.installPackages`. // TODO: needed?
        owners.delete(packageManagerOrBootstrapper); // delete bootstrapper

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

    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = ?actor(Principal.toText(indirectCaller)); // TODO: Remove `?`.
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

    stable var nextInstallationId: Common.InstallationId = 0;
    stable var nextUninstallationId: Common.UninstallationId = 0;
    stable var nextUpgradeId: Common.UpgradeId = 0;

    stable var _installedPackagesSave: [(Common.InstallationId, Common.SharedInstalledPackageInfo)] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo> =
        HashMap.HashMap(0, Nat.equal, Common.IntHash);

    stable var _installedPackagesByNameSave: [(Blob, {
        all: RBTree.Tree<Common.InstallationId, ()>;
        default: Common.InstallationId;
    })] = [];
    var installedPackagesByName: HashMap.HashMap<Blob, {
        all: RBTree.RBTree<Common.InstallationId, ()>;
        var default: Common.InstallationId;
    }> =
        HashMap.HashMap(0, Blob.equal, Blob.hash);

    stable var _halfInstalledPackagesSave: [(Common.InstallationId, SharedHalfInstalledPackageInfo)] = [];
    // TODO: `var` or `let` here and in other places:
    var halfInstalledPackages: HashMap.HashMap<Common.InstallationId, HalfInstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Common.IntHash);

    stable var _halfUninstalledPackagesSave: [(Common.UninstallationId, SharedHalfUninstalledPackageInfo)] = [];
    // TODO: `var` or `let` here and in other places:
    var halfUninstalledPackages: HashMap.HashMap<Common.UninstallationId, HalfUninstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Common.IntHash);

    stable var _halfUpgradedPackagesSave: [(Common.UpgradeId, SharedHalfUpgradedPackageInfo)] = [];
    // TODO: `var` or `let` here and in other places:
    var halfUpgradedPackages: HashMap.HashMap<Common.UpgradeId, HalfUpgradedPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Common.IntHash);

    stable var repositories: [{canister: Principal; name: Text}] = []; // TODO: a more suitable type like `HashMap` or at least `Buffer`?

    // TODO: Copy this code to other modules:
    func onlyOwner(caller: Principal, msg: Text) {
        if (Option.isNull(owners.get(caller))) {
            Debug.trap(debug_show(caller) # " is not the owner: " # msg);
        };
    };

    public shared({caller}) func installPackages({ // TODO: Rename.
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async {minInstallationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackages");

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
                    repo: Common.RepositoryRO;
                },
                {
                    repo: Common.RepositoryRO;
                    packageName: Common.PackageName;
                    version: Common.Version;
                    preinstalledModules: [(Text, Principal)];
                }
            >(packages.vals(), func (p: {
                repo: Common.RepositoryRO;
                packageName: Common.PackageName;
                version: Common.Version;
            }) = {
                repo = p.repo;
                packageName = p.packageName;
                version = p.version;
                preinstalledModules = [];
            }));
            installPackages = true;
            pmPrincipal = Principal.fromActor(this);
            // objectToInstall = #package {packageName; version}; // TODO
            user;
            afterInstallCallback;
            bootstrapping = false;
        });
    };

    public shared({caller}) func uninstallPackages({ // TODO: Rename.
        packages: [Common.InstallationId];
        user: Principal;
    })
        : async {minUninstallationId: Common.UninstallationId}
    {
        onlyOwner(caller, "uninstallPackages");

        let minUninstallationId = nextUninstallationId;
        nextUninstallationId += Array.size(packages);
        var ourNextUninstallationId = minUninstallationId;

        label cycle for (installationId in packages.vals()) {
            let uninstallationId = ourNextUninstallationId;
            ourNextUninstallationId += 1;
            let ?pkg = installedPackages.get(installationId) else {
                continue cycle; // already uninstalled
            };
            halfUninstalledPackages.put(uninstallationId, {
                installationId;
                var remainingModules = pkg.modules.size();
            });
            let modules = pkg.modules;
            for (canister_id in modules.vals()) {
                ignore getSimpleIndirect().callAll([{
                    canister = Principal.fromText("aaaaa-aa");
                    name = "stop_canister";
                    data = to_candid({canister_id});
                    error = #keepDoing; // need to reach `onDeleteCanister`
                }, {
                    canister = Principal.fromText("aaaaa-aa");
                    name = "delete_canister";
                    data = to_candid({canister_id});
                    error = #keepDoing; // need to reach `onDeleteCanister`
                }, {
                    canister = Principal.fromActor(this);
                    name = "onDeleteCanister";
                    data = to_candid({uninstallationId});
                    error = #abort;
                }]);
            };
        };

        {minUninstallationId};
    };

    // public shared({caller}) func upgradePackages({
    //     packages: [{
    //         installationId: Common.InstallationId;
    //         packageName: Common.PackageName;
    //         version: Common.Version;
    //         repo: Common.RepositoryRO;
    //     }];
    //     user: Principal;
    //     arg: [Nat8];
    // })
    //     : async {minUpgradeId: Common.UpgradeId}
    // {
    //     onlyOwner(caller, "uninstallPackages");

    //     let minUpgradeId = nextUpgradeId;
    //     nextUpgradeId += Array.size(packages);
    //     var ourNextUpgradeId = minUpgradeId;

    //     label cycle for (package in packages.vals()) {
    //         let installationId = package.installationId;
    //         let uninstallationId = ourNextUpgradeId;
    //         ourNextUpgradeId += 1;
    //         let ?pkg = installedPackages.get(installationId) else {
    //             continue cycle; // already uninstalled
    //         };
    //         halfUpgradedPackages.put(uninstallationId, {
    //             // installationId;
    //             var remainingModules = pkg.modules.size();
    //         });
    //         let modules = pkg.modules;
    //         // FIXME: delete removed modules, create new modules
    //         // FIXME: update assets
    //         for (canister_id in modules.vals()) {
    //             let m: Common.Module = Common.shareModule(pkg.package.modules); // FIXME

    //             let wasmModuleLocation = Common.extractModuleLocation(wasmModule.code);
    //             let wasmModuleSourcePartition: Common.RepositoryRO = actor(Principal.toText(wasmModuleLocation.0)); // TODO: Rename.
    //             let wasm_module = await wasmModuleSourcePartition.getWasmModule(wasmModuleLocation.1);
    //             // TODO: user's callback
    //             ignore getSimpleIndirect().callAll([
    //             // {
    //             //     canister = Principal.fromText("aaaaa-aa");
    //             //     name = "stop_canister";
    //             //     data = to_candid({canister_id});
    //             //     error = #keepDoing; // need to reach `onDeleteCanister`
    //             // },
    //             {
    //                 canister = Principal.fromText("aaaaa-aa");
    //                 name = "install_code";
    //                 data = to_candid({arg; wasm_module; mode = #upgrade; canister_id});
    //                 error = #keepDoing; // need to reach `onUpgradeCanister`
    //             }, {
    //                 canister = Principal.fromActor(this);
    //                 name = "onUpgradeCanister";
    //                 data = to_candid({uninstallationId});
    //                 error = #abort;
    //             }]);
    //         };
    //     };

    //     {minUpgradeId};
    // };

    /// Internal
    public shared({caller}) func onDeleteCanister({
        uninstallationId: Common.UninstallationId;
    }): async () {
        Debug.print("onDeleteCanister"); // FIXME: Remove.
        onlyOwner(caller, "onDeleteCanister");

        let ?uninst = halfUninstalledPackages.get(uninstallationId) else {
            return;
        };
        uninst.remainingModules -= 1;
        Debug.print("uninst.remainingModules: " # debug_show(uninst.remainingModules)); // FIXME: Remove.
        if (uninst.remainingModules == 0) {
            Debug.print("uninst.installationId: " # debug_show(uninst.installationId)); // FIXME: Remove.
            let ?pkg = installedPackages.get(uninst.installationId) else {
                return;
            };
            Debug.print("A1"); // FIXME: Remove.
            installedPackages.delete(uninst.installationId);
            let guid2 = Common.amendedGUID(pkg.package.base.guid, pkg.package.base.name);
            switch (installedPackagesByName.get(guid2)) {
                case (?info) {
                    if (RBTree.size(info.all.share()) == 1) {
                        installedPackagesByName.delete(guid2);
                        info.default := 0;
                    } else {
                        info.all.delete(uninst.installationId);
                        if (info.default == uninst.installationId) {
                            let ?(last, ()) = info.all.entriesRev().next() else {
                                Debug.trap("programming error");
                            };
                            info.default := last;
                        };
                    }
                };
                case null {};
            };
            halfUninstalledPackages.delete(uninstallationId);
        };
    };

    /// Internal. Install packages after bootstrapping IC Pack.
    public shared({caller}) func bootstrapAdditionalPackages(
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }],
        user: Principal,
    ) {
        try {
            onlyOwner(caller, "bootstrapAdditionalPackages");

            ignore await this.installPackages({ // TODO: no need for shared call
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
        repo: Common.RepositoryRO; 
        user: Principal;
        indirectCaller: Principal;
        /// Additional packages to install after bootstrapping.
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
        preinstalledModules: [(Text, Principal)];
    })
        : async {minInstallationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackageWithPreinstalledModules");

        let minInstallationId = nextInstallationId;
        nextInstallationId += additionalPackages.size();

        // We first fully install the package manager, and only then other packages.
        await* _installModulesGroup({
            indirectCaller = actor(Principal.toText(indirectCaller));
            whatToInstall;
            minInstallationId;
            packages = [{packageName; version; repo; preinstalledModules}]; // HACK
            installPackages = true; // TODO
            pmPrincipal = Principal.fromActor(this);
            // objectToInstall = #package {packageName; version}; // TODO
            user;
            afterInstallCallback = ?{
                canister = Principal.fromActor(this);
                name = "bootstrapAdditionalPackages";
                data = to_candid(additionalPackages, user);
            };
            bootstrapping = true;
        });
    };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    ///
    // public shared({caller}) func installNamedModules({
    //     repo: Common.RepositoryRO; // TODO: Install from multiple repos.
    //     modules: [(Text, Common.SharedModule)]; //  installArg, initArg
    //     avoidRepeated: Bool;
    //     user: Principal;
    //     preinstalledModules: [(Text, Principal)];
    // }): async {installationId: Common.InstallationId} {
    //     onlyOwner(caller, "installNamedModule");
    // };

    // TODO
    type ObjectToInstall = {
        #package : {
            packageName: Common.PackageName;
            version: Common.Version;
        };
        #namedModules : {
            dest: Common.InstallationId;
            modules: [{name: Text; installArg: Blob; initArg: ?Blob}];
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
        minInstallationId: Common.InstallationId;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        user: Principal;
        packages: [{
            package: Common.SharedPackageInfo;
            repo: Common.RepositoryRO;
            preinstalledModules: [(Text, Principal)];
        }];
        bootstrapping: Bool;
    }) {
        onlyOwner(caller, "installStart");

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

            let ourHalfInstalled: HalfInstalledPackageInfo = {
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
                bootstrapping;
            };
            halfInstalledPackages.put(minInstallationId + p0, ourHalfInstalled);

            for ((p0, pkg) in halfInstalledPackages.entries()) {
                await* doInstallFinish(p0, pkg);
            };
        };
    };

    private func doInstallFinish(p0: Common.InstallationId, pkg: HalfInstalledPackageInfo): async* () {
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

        let bi = if (pkg.bootstrapping) {
            // TODO: hack (instead should base this list on package description)
            [("backend", Principal.fromActor(this)), ("indirect", Principal.fromActor(getIndirectCaller())), ("simple_indirect", Principal.fromActor(getSimpleIndirect()))];
        } else {
            let ?pkg0 = installedPackages.get(0) else {
                Debug.trap("package manager not installed");
            };
            Iter.toArray(pkg0.modules.entries()); // TODO: inefficient?
        };
        let coreModules = HashMap.fromIter<Text, Principal>(bi.vals(), bi.size(), Text.equal, Text.hash);
        var moduleNumber = 0;
        let ?backend = coreModules.get("backend") else {
            Debug.trap("error getting backend");
        };
        let ?indirect = coreModules.get("indirect") else {
            Debug.trap("error getting indirect");
        };
        let ?simple_indirect = coreModules.get("simple_indirect") else {
            Debug.trap("error getting simple_indirect");
        };
        // The following (typically) does not overflow cycles limit, because we use an one-way function.
        var i = 0;
        for ((name, m): (Text, Common.Module) in modules) {
            // Starting installation of all modules in parallel:
            getIndirectCaller().installModule({
                installPackages = true/*whatToInstall == #package*/; // TODO: correct?
                moduleNumber;
                moduleName = ?name;
                installArg = to_candid({
                    installationId = p0;
                    packageManagerOrBootstrapper = backend;
                }); // TODO: Add more arguments.
                installationId = p0;
                packageManagerOrBootstrapper = backend;
                indirectCaller = indirect;
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
            // let ?inst2 = installedPackages.get(installationId) else {
            //     Debug.trap("no such installationId: " # debug_show(installationId));
            // };
            switch (inst.whatToInstall) {
                // case (#simplyModules _) {
                //     inst2.allModules.add(canister);
                //     switch (moduleName) {
                //         case (?moduleName) {
                //             inst2.allModules.add(canister);
                //             inst2.modules.put(moduleName, canister);
                //         };
                //         case null {};
                //     };
                // };
                case (#package) {
                    // Package modules are updated after installation of all modules.
                    // TODO: Do it here instead.
                }
            };
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
                        ignore getSimpleIndirect().callAll([{
                            canister = cbPrincipal;
                            name = callbackName.method;
                            data = to_candid({ // TODO
                                installationId;
                                canister;
                                user;
                                packageManagerOrBootstrapper; // TODO: Remove?
                                module_;
                            });
                            error = #abort;
                        }]);
                    };
                    case (null) {};
                };
            };
            switch (afterInstallCallback) {
                case (?afterInstallCallback) {
                    ignore getSimpleIndirect().callAll([{
                        canister = afterInstallCallback.canister;
                        name = afterInstallCallback.name;
                        data = afterInstallCallback.data;
                        error = #abort; // TODO: Here it's superfluous.
                    }]);
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
                    name = ourHalfInstalled.package.base.name;
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
                let tree = switch (installedPackagesByName.get(guid2)) {
                    case (?old) {
                        old.all;
                    };
                    case null {
                        let tree = RBTree.RBTree<Common.InstallationId, ()>(Nat.compare);
                        installedPackagesByName.put(guid2, {
                            all = tree;
                            var default = installationId;
                        });
                        tree;
                    };
                };
                tree.put(installationId, ());
            };
            // case (#simplyModules _) {};
        };
    };

    //     let ?installation = installedPackages.get(installationId) else {
    //         Debug.trap("no such installed installation");
    //     };
    //     let part: Repository.Repository = actor (Principal.toText(installation.packageRepoCanister));
    //     let packageInfo = await part.getPackage(installation.name, installation.version);

    //     let ourHalfInstalled: HalfInstalledPackageInfo = {
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
    //     // let part: Common.RepositoryRO = actor (Principal.toText(canister));
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
    //     ourHalfInstalled: HalfInstalledPackageInfo;
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
                (Blob, {all: RBTree.RBTree<Common.InstallationId, ()>; var default: Common.InstallationId}),
                (Blob, {all: RBTree.Tree<Common.InstallationId, ()>; default: Common.InstallationId})
            >(
                installedPackagesByName.entries(),
                func (x: (Blob, {all: RBTree.RBTree<Common.InstallationId, ()>; var default: Common.InstallationId})) {
                    (
                        x.0,
                        {all = x.1.all.share(); default = x.1.default},
                    );
                },
            ),
        );

        _halfInstalledPackagesSave := Iter.toArray(Iter.map<(Common.InstallationId, HalfInstalledPackageInfo), (Common.InstallationId, SharedHalfInstalledPackageInfo)>(
            halfInstalledPackages.entries(),
            func (elt: (Common.InstallationId, HalfInstalledPackageInfo)) = (elt.0, shareHalfInstalledPackageInfo(elt.1)),
        ));

        _halfUninstalledPackagesSave := Iter.toArray(Iter.map<(Common.UninstallationId, HalfUninstalledPackageInfo), (Common.UninstallationId, SharedHalfUninstalledPackageInfo)>(
            halfUninstalledPackages.entries(),
            func (elt: (Common.InstallationId, HalfUninstalledPackageInfo)) = (elt.0, shareHalfUninstalledPackageInfo(elt.1)),
        ));

        _halfUpgradedPackagesSave := Iter.toArray(Iter.map<(Common.UpgradeId, HalfUpgradedPackageInfo), (Common.UpgradeId, SharedHalfUpgradedPackageInfo)>(
            halfUninstalledPackages.entries(),
            func (elt: (Common.UpgradeId, HalfUpgradedPackageInfo)) = (elt.0, shareHalfUpgradedPackageInfo(elt.1)),
        ));
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
            ),
            Array.size(_installedPackagesSave),
            Nat.equal,
            Common.IntHash,
        );
        _installedPackagesSave := []; // Free memory.

        installedPackagesByName := HashMap.fromIter(
            Iter.map<
                (Blob, {all: RBTree.Tree<Common.InstallationId, ()>; default: Common.InstallationId}),
                (Blob, {all: RBTree.RBTree<Common.InstallationId, ()>; var default: Common.InstallationId})
            >(
                _installedPackagesByNameSave.vals(),
                func ((name, x): (Blob, {all: RBTree.Tree<Common.InstallationId, ()>; default: Common.InstallationId})) {
                    let tree = RBTree.RBTree<Common.InstallationId, ()>(Nat.compare);
                    tree.unshare(x.all);
                    (name, {all = tree; var default = x.default});
                },
            ),
            Array.size(_installedPackagesByNameSave),
            Blob.equal,
            Blob.hash,
        );
        _installedPackagesByNameSave := []; // Free memory.

        halfInstalledPackages := HashMap.fromIter<Common.InstallationId, HalfInstalledPackageInfo>(
            Iter.map<(Common.InstallationId, SharedHalfInstalledPackageInfo), (Common.InstallationId, HalfInstalledPackageInfo)>(
                _halfInstalledPackagesSave.vals(),
                func (x: (Common.InstallationId, SharedHalfInstalledPackageInfo)) = (x.0, unshareHalfInstalledPackageInfo(x.1)),
            ),
            _halfInstalledPackagesSave.size(),
            Nat.equal,
            Common.IntHash,
        );
        _halfInstalledPackagesSave := []; // Free memory.
        halfUninstalledPackages := HashMap.fromIter<Common.UninstallationId, HalfUninstalledPackageInfo>(
            Iter.map<(Common.UninstallationId, SharedHalfUninstalledPackageInfo), (Common.UninstallationId, HalfUninstalledPackageInfo)>(
                _halfUninstalledPackagesSave.vals(),
                func (x: (Common.UninstallationId, SharedHalfUninstalledPackageInfo)) = (x.0, unshareHalfUninstalledPackageInfo(x.1)),
            ),
            _halfInstalledPackagesSave.size(),
            Nat.equal,
            Common.IntHash,
        );
        _halfUninstalledPackagesSave := []; // Free memory.
        halfUpgradedPackages := HashMap.fromIter<Common.UpgradeId, HalfUpgradedPackageInfo>(
            Iter.map<(Common.UpgradeId, SharedHalfUpgradedPackageInfo), (Common.UpgradeId, HalfUpgradedPackageInfo)>(
                _halfUpgradedPackagesSave.vals(),
                func (x: (Common.UpgradeId, SharedHalfUpgradedPackageInfo)) = (x.0, unshareHalfUpgradedPackageInfo(x.1)),
            ),
            _halfUpgradedPackagesSave.size(),
            Nat.equal,
            Common.IntHash,
        );
        _halfUpgradedPackagesSave := []; // Free memory.
    };

    // Accessor method //

    public query({caller}) func getInstalledPackage(id: Common.InstallationId): async Common.SharedInstalledPackageInfo {
        onlyOwner(caller, "getInstalledPackage");

        let ?result = installedPackages.get(id) else {
            Debug.trap("no such installed package");
        };
        Common.installedPackageInfoShare(result);
    };

    public query({caller}) func getInstalledPackagesInfoByName(name: Text, guid: Blob)
        : async {all: [Common.SharedInstalledPackageInfo]; default: Common.InstallationId}
    {
        onlyOwner(caller, "getInstalledPackagesInfoByName");

        let guid2 = Common.amendedGUID(guid, name);
        let ?data = installedPackagesByName.get(guid2) else {
            return {all = []; default = 0};
        };
        let all = Iter.toArray(Iter.map<(Common.InstallationId, ()), Common.SharedInstalledPackageInfo>(
            data.all.entries(),
            func (id: Common.InstallationId, _: ()): Common.SharedInstalledPackageInfo {
                let ?info = installedPackages.get(id) else {
                    Debug.trap("getInstalledPackagesInfoByName: programming error");
                };
                Common.installedPackageInfoShare(info);
            }));
        {all; default = data.default};
    };

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

    /// Internal.
    public query({caller}) func getHalfInstalledPackages(): async [{
        installationId: Common.InstallationId;
        packageRepoCanister: Principal;
        name: Common.PackageName;
        version: Common.Version;
    }] {
        onlyOwner(caller, "getHalfInstalledPackages");

        Iter.toArray(Iter.map<(Common.InstallationId, HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            packageRepoCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        }>(halfInstalledPackages.entries(), func (x: (Common.InstallationId, HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            packageRepoCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        } =
            {
                installationId = x.0;
                packageRepoCanister = x.1.packageRepoCanister;
                name = x.1.package.base.name;
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
            repo: Common.RepositoryRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
        }];
        pmPrincipal: Principal;
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        bootstrapping: Bool;
    })
        : async* {minInstallationId: Common.InstallationId}
    {
        indirectCaller.installPackageWrapper({
            whatToInstall;
            minInstallationId;
            packages;
            pmPrincipal;
            user;
            afterInstallCallback;
            bootstrapping;
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