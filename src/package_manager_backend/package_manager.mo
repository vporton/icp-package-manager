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
import RBTree "mo:base/RBTree";
import Common "../common";
import MainIndirect "main_indirect";
import SimpleIndirect "simple_indirect";

shared({caller = initialCaller}) actor class PackageManager({
    packageManagerOrBootstrapper: Principal;
    mainIndirect: Principal;
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
        package: Common.PackageInfo;
        packageRepoCanister: Principal;
        namedModules: HashMap.HashMap<Text, Principal>; // TODO: Rename.
        allModules: Buffer.Buffer<Principal>;
        minInstallationId: Nat; // hack 
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    
        bootstrapping: Bool;
        var remainingModules: Nat;
    };

    public type SharedHalfInstalledPackageInfo = {
        package: Common.SharedPackageInfo;
        packageRepoCanister: Principal;
        namedModules: [(Text, Principal)];
        allModules: [Principal];
        minInstallationId: Nat; // hack 
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        bootstrapping: Bool;
        remainingModules: Nat;
    };

    private func shareHalfInstalledPackageInfo(x: HalfInstalledPackageInfo): SharedHalfInstalledPackageInfo = {
        package = Common.sharePackageInfo(x.package);
        packageRepoCanister = x.packageRepoCanister;
        namedModules = Iter.toArray(x.namedModules.entries());
        allModules = Buffer.toArray(x.allModules);
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        bootstrapping = x.bootstrapping;
        remainingModules = x.remainingModules;
    };

    private func unshareHalfInstalledPackageInfo(x: SharedHalfInstalledPackageInfo): HalfInstalledPackageInfo = {
        package = Common.unsharePackageInfo(x.package);
        packageRepoCanister = x.packageRepoCanister;
        namedModules = HashMap.fromIter(x.namedModules.vals(), x.namedModules.size(), Text.equal, Text.hash);
        allModules = Buffer.fromArray(x.allModules);
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        bootstrapping = x.bootstrapping;
        var remainingModules = x.remainingModules;
    };

    public type HalfUninstalledPackageInfo = {
        installationId: Common.InstallationId;
        var remainingModules: Nat;
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
        installationId: Common.InstallationId;
        package: Common.PackageInfo;
        namedModules: HashMap.HashMap<Text, Principal>;
        allModules: Buffer.Buffer<Principal>;
        modulesToDelete: [(Text, Principal)];
        var remainingModules: Nat;
    };

    public type SharedHalfUpgradedPackageInfo = {
        installationId: Common.InstallationId;
        package: Common.SharedPackageInfo;
        namedModules: [(Text, Principal)]; // TODO: Rename.
        allModules: [Principal];
        modulesToDelete: [(Text, Principal)];
        remainingModules: Nat;
    };

    private func shareHalfUpgradedPackageInfo(x: HalfUpgradedPackageInfo): SharedHalfUpgradedPackageInfo = {
        installationId = x.installationId;
        package = Common.sharePackageInfo(x.package);
        namedModules = Iter.toArray(x.namedModules.entries());
        allModules = Buffer.toArray(x.allModules);
        modulesToDelete = x.modulesToDelete;
        remainingModules = x.remainingModules;
    };

    private func unshareHalfUpgradedPackageInfo(x: SharedHalfUpgradedPackageInfo): HalfUpgradedPackageInfo = {
        installationId = x.installationId;
        package = Common.unsharePackageInfo(x.package);
        namedModules = HashMap.fromIter(x.namedModules.vals(), x.namedModules.size(), Text.equal, Text.hash);
        allModules = Buffer.fromArray(x.allModules);
        modulesToDelete = x.modulesToDelete;
        var remainingModules = x.remainingModules;
    };

    stable var initialized = false;

    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter(
            [
                (packageManagerOrBootstrapper, ()),
                (mainIndirect, ()), // temporary
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
        let a = getMainIndirect().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
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

    stable var main_indirect_: ?MainIndirect.MainIndirect = ?actor(Principal.toText(mainIndirect)); // TODO: Remove `?`.
    stable var simple_indirect_: ?SimpleIndirect.SimpleIndirect = ?actor(Principal.toText(simpleIndirect)); // TODO: Remove `?`.

    private func getMainIndirect(): MainIndirect.MainIndirect {
        let ?main_indirect_2 = main_indirect_ else {
            Debug.trap("main_indirect_ not initialized");
        };
        main_indirect_2;
    };

    private func getSimpleIndirect(): SimpleIndirect.SimpleIndirect {
        let ?simple_indirect_2 = simple_indirect_ else {
            Debug.trap("simple_indirect_ not initialized");
        };
        simple_indirect_2;
    };

    // TODO: too low-level?
    public shared({caller}) func setMainIndirect(main_indirect_v: MainIndirect.MainIndirect): async () {
        onlyOwner(caller, "setMainIndirect");

        main_indirect_ := ?main_indirect_v;
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

    public shared({caller}) func installPackages({
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
        user: Principal;
        afterInstallCallback: ?{ // TODO: Remove it from this function?
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async {minInstallationId: Common.InstallationId}
    {
        onlyOwner(caller, "installPackages");

        let minInstallationId = nextInstallationId;
        nextInstallationId += packages.size();

        await* _installModulesGroup({ // TODO: Rename this function.
            mainIndirect = getMainIndirect();
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
            pmPrincipal = Principal.fromActor(this);
            user;
            afterInstallCallback;
            bootstrapping = false;
        });
    };

    public shared({caller}) func uninstallPackages({
        packages: [Common.InstallationId]; // TODO: Use `packageIds` argument name here and in other functions.
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
                var remainingModules = pkg.namedModules.size();
            });
            let modules = pkg.namedModules;
            for (canister_id in modules.vals()) {
                ignore getSimpleIndirect().callAll([{
                    canister = Principal.fromText("aaaaa-aa");
                    name = "stop_canister";
                    data = to_candid({canister_id});
                    error = #abort;
                }, {
                    canister = Principal.fromText("aaaaa-aa");
                    name = "delete_canister";
                    data = to_candid({canister_id});
                    error = #abort;
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

    /// We first add new and upgrade existing modules (including executing hooks)
    /// and only then delete modules to be deleted. That's because deleted modules may contain
    /// important data that needs to be imported. Also having deleting modules at the end
    /// does not prevent the package to start fully function before this.
    public shared({caller}) func upgradePackages({
        packages: [{
            installationId: Common.InstallationId;
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
        pmPrincipal: Principal;
        user: Principal;
        arg: Blob;
    })
        : async {minUpgradeId: Common.UpgradeId}
    {
        onlyOwner(caller, "upgradePackages");

        let minUpgradeId = nextUpgradeId;
        nextUpgradeId += Array.size(packages);

        getMainIndirect().upgradePackageWrapper({
            minUpgradeId;
            packages;
            pmPrincipal;
            user;
            arg;
        });

        {minUpgradeId};
    };

    /// Internal.
    public shared({caller}) func upgradeStart({
        minUpgradeId: Common.UpgradeId;
        user: Principal;
        packages: [{
            installationId: Common.InstallationId;
            package: Common.SharedPackageInfo;
            repo: Common.RepositoryRO;
        }];
    }): async () {
        onlyOwner(caller, "upgradeStart");

        for (p0 in packages.keys()) {
            let p = Common.unsharePackageInfo(packages[p0].package); // Need to unshare the entire variable?
            // let #real realPackage = p.specific else {
            //     Debug.trap("trying to directly install a virtual package");
            // };
            let newPkg = p; // TODO
            let #real newPkgSpecific = p.specific else {
                Debug.trap("trying to directly install a virtual package");
            };
            // TODO: virtual packages; upgrading a real package into virtual or vice versa
            let newPkgModules = newPkgSpecific.modules;
            let newPkgModulesHash = newPkgSpecific.modules; // TODO: HashMap.fromIter<Text, Common.Module>(newPkgModules.vals(), newPkgModules.size(), Text.equal, Text.hash);
            let ?oldPkg = installedPackages.get(packages[p0].installationId) else {
                Debug.trap("no such package installation");
            };
            let #specific oldPkgSpecific = oldPkg.package.specific else {
                Debug.trap("trying to directly upgrade a virtual package");
            };
            // let oldPkgModules = oldPkgSpecific.modules;
            // let oldPkgModulesHash = HashMap.fromIter<Text, Common.Module>(oldPkgModules.entries(), oldPkgModules.size(), Text.equal, Text.hash);

            let modulesToDelete0 = HashMap.fromIter<Text, Common.Module>(
                Iter.filter<(Text, Common.Module)>(
                    oldPkgSpecific.modules.entries(),
                    func (x: (Text, Common.Module)) = Option.isNull(newPkgModulesHash.get(x.0))
                ),
                oldPkgSpecific.modules.size(), // TODO: It can be smaller.
                Text.equal,
                Text.hash
            );
            let modulesToDelete = Iter.toArray(
                Iter.map<Text, (Text, Principal)>(
                    modulesToDelete0.keys(),
                    func (name: Text) {
                        let ?m = oldPkgSpecific.modules.get(name) else {
                            Debug.trap("programming error");
                        };
                        (name, m.canister);
                    }
                )
            );

            // let package2 = Common.unsharePackageInfo(packages[p0].package); // Possibly redundant.
            // let numModules = realPackage.modules.size();

            halfUpgradedPackages.put(minUpgradeId + p0, {
                upgradeId = minUpgradeId + p0;
                installationId = packages[p0].installationId;
                package = newPkg;
                namedModules = HashMap.HashMap(0, Text.equal, Text.hash);
                allModules = Buffer.Buffer(0);
                modulesToDelete;
                var remainingModules = newPkgModules.size() - modulesToDelete.size();
            });

            // Finish upgrading modules.
            for ((p0, pkg) in halfUpgradedPackages.entries()) {
                await* doUpgradeFinish(p0, pkg, packages[p0].installationId, user); // TODO: Use named arguments.
            };
        };
    };

    /// Internal
    public shared({caller}) func onUpgradeOrInstallModule({
        upgradeId: Common.UpgradeId;
    }): async () {
        onlyOwner(caller, "onUpgradeOrInstallModule");

        let ?upgrade = halfUpgradedPackages.get(upgradeId) else {
            Debug.trap("no such upgrade");
        };
        upgrade.remainingModules -= 1;
        if (upgrade.remainingModules == 0) {
            for ((moduleName, canister_id) in upgrade.modulesToDelete.vals()) {
                // `ignore` protects against non-returning-function attack.
                // Another purpose of `ignore` to finish the uninstallation even if a module was previously remove.
                ignore getSimpleIndirect().callAll([{
                    canister = Principal.fromText("aaaaa-aa");
                    name = "stop_canister";
                    data = to_candid({canister_id});
                    error = #abort;
                }, {
                    canister = Principal.fromText("aaaaa-aa");
                    name = "delete_canister";
                    data = to_candid({canister_id});
                    error = #abort;
                }]);
                upgrade.namedModules.put(moduleName, canister_id);
                upgrade.allModules.add(canister_id);
            };
            halfUpgradedPackages.delete(upgradeId);
        };

        // Call the user's callback if provided
        let #real specific = upgrade.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        let ?inst = halfInstalledPackages.get(upgrade.installationId) else {
            Debug.trap("no such installed package");
        };
        for ((moduleName2, module4) in specific.modules.entries()) {
            let ?cbPrincipal = inst.namedModules.get(moduleName2) else {
                Debug.trap("programming error 3");
            };
            switch (module4.callbacks.get(#CodeUpgradedForAllCanisters)) {
                case (?callbackName) {
                    ignore getSimpleIndirect().callAll([{
                        canister = cbPrincipal;
                        name = callbackName.method;
                        data = to_candid({ // TODO
                            upgradeId;
                            installationId = upgrade.installationId;
                            packageManagerOrBootstrapper = Principal.fromActor(this);
                        });
                        error = #abort;
                    }]);
                };
                case (null) {};
            };
        };
    };

    /// Internal
    public shared({caller}) func onDeleteCanister({
        uninstallationId: Common.UninstallationId;
    }): async () {
        Debug.print("onDeleteCanister");

        onlyOwner(caller, "onDeleteCanister");

        let ?uninst = halfUninstalledPackages.get(uninstallationId) else {
            return;
        };
        uninst.remainingModules -= 1;
        if (uninst.remainingModules == 0) {
            let ?pkg = installedPackages.get(uninst.installationId) else {
                return;
            };
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
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryRO; 
        user: Principal;
        mainIndirect: Principal;
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
            mainIndirect = actor(Principal.toText(mainIndirect));
            minInstallationId;
            packages = [{packageName; version; repo; preinstalledModules}]; // HACK
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

            let preinstalledModules = HashMap.fromIter<Text, Principal>(
                p.preinstalledModules.vals(), p.preinstalledModules.size(), Text.equal, Text.hash);

            let ourHalfInstalled: HalfInstalledPackageInfo = {
                package = package2;
                packageRepoCanister = Principal.fromActor(p.repo); // TODO: Make packageRepoCanister to be of actor type.
                namedModules = preinstalledModules;
                allModules = Buffer.Buffer(0);
                minInstallationId;
                afterInstallCallback;
                bootstrapping;
                var remainingModules = numModules;
            };
            halfInstalledPackages.put(minInstallationId + p0, ourHalfInstalled);

            // TODO: Use it to be able to finish an interrupted installation:
            for ((p0, pkg) in halfInstalledPackages.entries()) {
                await* doInstallFinish(p0, pkg);
            };
        };
    };

    // TODO: Check that all useful code has been moved from here and delete this function.
    private func doInstallFinish(p0: Common.InstallationId, pkg: HalfInstalledPackageInfo): async* () {
        let p = pkg.package;
        let modules: Iter.Iter<(Text, Common.Module)> =
            switch (p.specific) {
                case (#real pkgReal) {
                    Iter.filter<(Text, Common.Module)>(
                        pkgReal.modules.entries(),
                        func (p: (Text, Common.Module)) = p.1.installByDefault,
                    );
                };
                case (#virtual _) [].vals();
            };

        let bi = if (pkg.bootstrapping) {
            // TODO: hack (instead should base this list on package description)
            [("backend", Principal.fromActor(this)), ("indirect", Principal.fromActor(getMainIndirect())), ("simple_indirect", Principal.fromActor(getSimpleIndirect()))];
        } else {
            let ?pkg0 = installedPackages.get(0) else {
                Debug.trap("package manager not installed");
            };
            Iter.toArray(pkg0.namedModules.entries()); // TODO: inefficient?
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
            getMainIndirect().installModule({
                moduleNumber;
                moduleName = ?name;
                installArg = to_candid({}); // TODO: Add more arguments.
                installationId = p0;
                packageManagerOrBootstrapper = backend;
                mainIndirect = indirect;
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

    private func doUpgradeFinish(p0: Common.UpgradeId, pkg: HalfUpgradedPackageInfo, installationId: Common.InstallationId, user: Principal): async* () {
        var posTmp = 0;
        let #real newPkgSpecific = pkg.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        // TODO: upgrading a real package into virtual or vice versa
        let newPkgModules = newPkgSpecific.modules;

        // TODO: repeated calculation
        let ?oldPkg = installedPackages.get(pkg.installationId) else {
            Debug.trap("no such package installation");
        };
        // let #specific oldPkgSpecific = oldPkg.package.specific else {
        //     Debug.trap("trying to directly upgrade a virtual package");
        // };
        // let oldPkgModules = oldPkgSpecific.modules; // Corrected: Use oldPkgSpecific modules.
        // let oldPkgModulesHash = HashMap.fromIter<Text, Common.Module>(oldPkgModules.entries(), oldPkgModules.size(), Text.equal, Text.hash);

        for (name in newPkgModules.keys()) {
            let pos = posTmp;
            posTmp += 1;

            let canister_id = oldPkg.namedModules.get(name);
            let ?wasmModule = newPkgModules.get(name) else {
                Debug.trap("programming error: no such module");
            };
            getMainIndirect().upgradeOrInstallModule({
                upgradeId = p0 + pos;
                installationId;
                canister_id;
                user;
                wasmModule = Common.shareModule(wasmModule);
                arg = to_candid({
                    packageManagerOrBootstrapper;
                    mainIndirect;
                    simpleIndirect;
                    user;
                    installationId;
                    userArg = to_candid({}); // TODO
                });
                installArg = to_candid({ // TODO: Add more arguments.
                    installationId = p0;
                    packageManagerOrBootstrapper = Principal.fromActor(this);
                });
                upgradeArg = to_candid({ // TODO: Add more arguments.
                    installationId = p0;
                    packageManagerOrBootstrapper = Principal.fromActor(this);
                });
                moduleName = name;
                moduleNumber = pos;
                packageManagerOrBootstrapper = Principal.fromActor(this);
                mainIndirect;
                simpleIndirect;
            });
        };
    };

    /// Internal
    public shared({caller}) func onInstallCode({
        installationId: Common.InstallationId;
        canister: Principal;
        moduleNumber: Nat; // TODO: Use it.
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
        switch (moduleName) {
            case (?name) {
                inst.namedModules.put(name, canister);
            };
            case null {};
        };
        inst.allModules.add(canister); // TODO: automated test for this
        let #real realPackage = inst.package.specific else { // TODO: fails with virtual packages
            Debug.trap("trying to directly install a virtual installation");
        };
        // Note that we have different algorithms for zero and non-zero number of callbacks (TODO: check).
        inst.remainingModules -= 1;
        if (inst.remainingModules == 0) { // All module have been installed.
            // TODO: order of this code
            _updateAfterInstall({installationId});
            for ((moduleName2, module4) in realPackage.modules.entries()) {
                switch (module4.callbacks.get(#CodeInstalledForAllCanisters)) {
                    case (?callbackName) {
                        let ?cbPrincipal = inst.namedModules.get(moduleName2) else {
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
                                moduleNumber;
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

    // TODO: Keep registry of ALL installed modules.
    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        installedPackages.put(installationId, {
            id = installationId;
            package = ourHalfInstalled.package;
            packageRepoCanister = ourHalfInstalled.packageRepoCanister;
            namedModules = ourHalfInstalled.namedModules; // no need for deep copy, because we delete `ourHalfInstalled` soon
            allModules = ourHalfInstalled.allModules;
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
    //         getMainIndirect().callAllOneWay([
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
            halfUpgradedPackages.entries(),
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
        package: Common.SharedPackageInfo;
    }] {
        onlyOwner(caller, "getHalfInstalledPackages");

        Iter.toArray(Iter.map<(Common.InstallationId, HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            package: Common.SharedPackageInfo;
        }>(halfInstalledPackages.entries(), func (x: (Common.InstallationId, HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            package: Common.SharedPackageInfo;
        } =
            {
                installationId = x.0;
                package = Common.sharePackageInfo(x.1.package);
            },
        ));
    };

    /// TODO: very unstable API.
    public query({caller}) func getHalfInstalledPackageModulesById(installationId: Common.InstallationId): async [(Text, Principal)] {
        onlyOwner(caller, "getHalfInstalledPackageModulesById");

        let ?res = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        // TODO: May be a little bit slow.
        Iter.toArray<(Text, Principal)>(res.namedModules.entries());
    };

    // TODO: Rearrage functions, possible rename:
    private func _installModulesGroup({
        mainIndirect: MainIndirect.MainIndirect;
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
        mainIndirect.installPackagesWrapper({
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