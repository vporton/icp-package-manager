/// TODO@P3: Methods to query for all installed packages.
import Result "mo:core/Result";
import List "mo:core/List";
import Option "mo:core/Option";
import Map "mo:core/Map";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Int "mo:core/Int";
import Float "mo:core/Float";
import Blob "mo:core/Blob";
import Bool "mo:core/Bool";
import Error "mo:core/Error";
import Cycles "mo:core/Cycles";
import Common "../common";
import MainIndirect "main_indirect";
import SimpleIndirect "simple_indirect";
import CyclesLedger "canister:cycles_ledger";
import Asset "mo:assets-api";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import IC "mo:ic";
import LIB "mo:icpack-lib";
import env "mo:env";
// import Account "mo:icrc1/ICRC1/Account";
import Battery "battery";
import Install "../install";

shared({caller = initialCaller}) persistent actor class PackageManager({
    packageManager: Principal; // may be the bootstrapper instead.
    mainIndirect: Principal;
    simpleIndirect: Principal;
    battery: Principal;
    user: Principal;
    installationId: Common.InstallationId;
    userArg = _: Blob;
}) = this {
    // let ?userArgValue: ?{
    // } = from_candid(userArg) else {
    //     throw Error.reject("argument userArg is wrong");
    // };

    public type HalfInstalledPackageInfo = {
        package: Common.PackageInfo;
        packageRepoCanister: Principal;
        modulesInstalledByDefault: Map.Map<Text, Principal>;
        minInstallationId: Nat; // hack
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };    
        bootstrapping: Bool;
        var remainingModules: Nat;
        arg: Blob;
        initArg: ?Blob;
    };

    public type SharedHalfInstalledPackageInfo = {
        package: Common.SharedPackageInfo;
        packageRepoCanister: Principal;
        modulesInstalledByDefault: [(Text, Principal)];
        minInstallationId: Nat; // hack
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
        bootstrapping: Bool;
        remainingModules: Nat;
        arg: Blob;
        initArg: ?Blob;
    };

    private func shareHalfInstalledPackageInfo(x: HalfInstalledPackageInfo): SharedHalfInstalledPackageInfo = {
        package = Common.sharePackageInfo(x.package);
        packageRepoCanister = x.packageRepoCanister;
        modulesInstalledByDefault = Iter.toArray(Map.entries(x.modulesInstalledByDefault));
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        bootstrapping = x.bootstrapping;
        remainingModules = x.remainingModules;
        arg = x.arg;
        initArg = x.initArg;
    };

    private func unshareHalfInstalledPackageInfo(x: SharedHalfInstalledPackageInfo): HalfInstalledPackageInfo = {
        package = Common.unsharePackageInfo(x.package);
        packageRepoCanister = x.packageRepoCanister;
        modulesInstalledByDefault = Map.fromIter(x.modulesInstalledByDefault.vals(), Text.compare);
        minInstallationId = x.minInstallationId;
        afterInstallCallback = x.afterInstallCallback;
        bootstrapping = x.bootstrapping;
        var remainingModules = x.remainingModules;
        arg = x.arg;
        initArg = x.initArg;
    };

    public type HalfUninstalledPackageInfo = {
        installationId: Common.InstallationId;
        package: Common.PackageInfo;
        var remainingModules: Nat;
    };

    public type SharedHalfUninstalledPackageInfo = {
        installationId: Common.InstallationId;
        package: Common.SharedPackageInfo;
        remainingModules: Nat;
    };

    private func shareHalfUninstalledPackageInfo(x: HalfUninstalledPackageInfo): SharedHalfUninstalledPackageInfo = {
        installationId = x.installationId;
        package = Common.sharePackageInfo(x.package);
        remainingModules = x.remainingModules;
    };

    private func unshareHalfUninstalledPackageInfo(x: SharedHalfUninstalledPackageInfo): HalfUninstalledPackageInfo = {
        installationId = x.installationId;
        package = Common.unsharePackageInfo(x.package);
        var remainingModules = x.remainingModules;
    };

    public type HalfUpgradedPackageInfo = {
        installationId: Common.InstallationId;
        package: Common.PackageInfo;
        newRepo: Principal;
        modulesInstalledByDefault: Map.Map<Text, Principal>;
        modulesToDelete: [(Text, Principal)];
        var remainingModules: Nat;
        arg: Blob;
        initArg: ?Blob;
    };

    public type SharedHalfUpgradedPackageInfo = {
        installationId: Common.InstallationId;
        package: Common.SharedPackageInfo;
        newRepo: Principal;
        modulesInstalledByDefault: [(Text, Principal)];
        modulesToDelete: [(Text, Principal)];
        remainingModules: Nat;
        arg: Blob;
        initArg: ?Blob;
    };

    private func shareHalfUpgradedPackageInfo(x: HalfUpgradedPackageInfo): SharedHalfUpgradedPackageInfo = {
        installationId = x.installationId;
        package = Common.sharePackageInfo(x.package);
        newRepo = x.newRepo;
        modulesInstalledByDefault = Iter.toArray(Map.entries(x.modulesInstalledByDefault));
        modulesToDelete = x.modulesToDelete;
        remainingModules = x.remainingModules;
        arg = x.arg;
        initArg = x.initArg;
    };

    private func unshareHalfUpgradedPackageInfo(x: SharedHalfUpgradedPackageInfo): HalfUpgradedPackageInfo = {
        installationId = x.installationId;
        package = Common.unsharePackageInfo(x.package);
        modulesInstalledByDefault = Map.fromIter(x.modulesInstalledByDefault.vals(), Text.compare);
        modulesToDelete = x.modulesToDelete;
        newRepo = x.newRepo;
        var remainingModules = x.remainingModules;
        arg = x.arg;
        initArg = x.initArg;
    };

    stable var initialized = false;

    stable var owners: Map.Map<Principal, ()> = // FIXME@P1: Use `Set`.
        Map.fromIter(
            [
                (packageManager, ()),
                (mainIndirect, ()), // temporary
                (simpleIndirect, ()),
                (battery, ()),
                (user, ()),
            ].vals(),
            Principal.compare);

    transient let batteryActor: Battery.Battery = actor(Principal.toText(battery));

    public shared({caller}) func init({
        // installationId: Common.InstallationId;
        // canister: Principal;
        // user: Principal;
        // packageManager: Principal;
    }): async () {
        try {
            switch (onlyOwner(caller, "init")) {
                case (#err err) {
                    throw Error.reject(err);
                };
                case (#ok) {};
            };

            ignore Map.insert(owners, Principal.compare, Principal.fromActor(this), ()); // self-usage to call `this.installPackages`. // TODO@P3: needed?
            ignore Map.delete(owners, Principal.compare, packageManager); // delete bootstrapper

            initialized := true;
        }
        catch(e) {
            Debug.print("PM init: " # Error.message(e));
            throw Error.reject(Error.message(e));
        };
    };

    public shared({caller}) func setOwners(newOwners: [Principal]): async () {
        switch (onlyOwner(caller, "setOwners")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        owners := Map.fromIter(
            Iter.map<Principal, (Principal, ())>(newOwners.vals(), func (owner: Principal): (Principal, ()) = (owner, ())),
            Principal.compare,
        );
    };

    public shared({caller}) func addOwner(newOwner: Principal): async () {
        switch (onlyOwner(caller, "addOwner")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        ignore Map.insert(owners, Principal.compare, newOwner, ());
    };

    public shared({caller}) func removeOwner(oldOwner: Principal): async () {
        switch (onlyOwner(caller, "removeOwner")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        ignore Map.delete(owners, Principal.compare, oldOwner);
    };

    public query func getOwners(): async [Principal] {
        Iter.toArray(Map.keys<Principal, ()>(owners));
    };

    public composite query func isAllInitialized(): async () {
        try {
            if (not initialized) {
                throw Error.reject("package_manager: not initialized");
            };
            // TODO@P3: need b44c4a9beec74e1c8a7acbe46256f92f_isInitialized() method in this canister, too? Maybe, remove the prefix?
            let _ = getMainIndirect().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
            let _ = getSimpleIndirect().b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
            let _ = batteryActor.b44c4a9beec74e1c8a7acbe46256f92f_isInitialized();
            let _ = do {
                let ?pkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId) else {
                    throw Error.reject("package manager is not yet installed");
                };
                let ?frontend = Map.get(pkg.modulesInstalledByDefault, Text.compare, "frontend") else {
                    throw Error.reject("programming error 1");
                };
                let f: Asset.AssetCanister = actor(Principal.toText(frontend));
                f.get({key = "/index.html"; accept_encodings = ["gzip"]});
            };
            // TODO@P3: https://github.com/dfinity/motoko/issues/4837
            // ignore {{a0 = await a; b0 = await b/*; c0 = await c; d0 = await d*/}}; // run in parallel
        }
        catch(e) {
            Debug.print("PM isAllInitialized: " # Error.message(e));
            throw Error.reject(Error.message(e));
        };
    };

    // TODO@P3: Rename:
    stable var main_indirect_: MainIndirect.MainIndirect = actor(Principal.toText(mainIndirect));
    stable var simple_indirect_: SimpleIndirect.SimpleIndirect = actor(Principal.toText(simpleIndirect));

    private func getMainIndirect(): MainIndirect.MainIndirect {
        main_indirect_;
    };

    private func getSimpleIndirect(): SimpleIndirect.SimpleIndirect {
        simple_indirect_;
    };

    // TODO@P3: too low-level?
    public shared({caller}) func setMainIndirect(main_indirect_v: MainIndirect.MainIndirect): async () {
        switch (onlyOwner(caller, "")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        main_indirect_ := main_indirect_v;
    };

    stable var nextInstallationId: Common.InstallationId = 0; // 0 is package manager.
    stable var nextUninstallationId: Common.UninstallationId = 0;
    stable var nextUpgradeId: Common.UpgradeId = 0;

    stable var installedPackages = Map.empty<Common.InstallationId, Common.InstalledPackageInfo>();

    var installedPackagesByName: Map.Map<Blob, {
        all: Map.Map<Common.InstallationId, ()>; // FIXME@P1: `Set`
        var default: Common.InstallationId;
    }> = Map.empty();
    // TODO@P3: `var` or `let` here and in other places:
    stable var halfInstalledPackages: Map.Map<Common.InstallationId, HalfInstalledPackageInfo> =
        Map.fromIter([].vals(), Int.compare); // TODO@P3: use `Nat.compare`?


    // TODO@P3: `var` or `let` here and in other places:
    stable var halfUninstalledPackages: Map.Map<Common.UninstallationId, HalfUninstalledPackageInfo> =
        Map.fromIter([].vals(), Int.compare); // TODO@P3: use `Nat.compare`?

    // TODO@P3: `var` or `let` here and in other places:
    stable var halfUpgradedPackages: Map.Map<Common.UpgradeId, HalfUpgradedPackageInfo> =
        Map.fromIter([].vals(), Int.compare); // TODO@P3: use `Nat.compare`?

    stable var repositories: [{canister: Principal; name: Text}] = [];

    // TODO@P3: Copy this code to other modules:
    func onlyOwner(caller: Principal, msg: Text): Result.Result<(), Text> {
        if (not env.isLocal and Option.isNull(Map.get<Principal, ()>(owners, Principal.compare, caller))) { // allow everybody on localhost, for debugging
            return #err(debug_show(caller) # " is not the owner: " # msg);
        };
        #ok;
    };

    /// Private helper function to prepare upgrade data structures
    private func prepareUpgradeData({
        installationId: Common.InstallationId;
        newPkg: Common.PackageInfo;
        newRepo: Principal;
        arg: Blob;
        initArg: ?Blob;
    }): Result.Result<{
        halfUpgradedInfo: HalfUpgradedPackageInfo;
        modulesToDelete: [(Text, Principal)];
        allModulesCount: Nat;
    }, Text> {
        let #real newPkgReal = newPkg.specific else {
            return #err("trying to directly upgrade a virtual package");
        };
        let newPkgModules = newPkgReal.modules;

        let ?oldPkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId) else {
            return #err("no such package installation");
        };
        let #real oldPkgReal = oldPkg.package.specific else {
            return #err("trying to directly upgrade a virtual package");
        };

        // Calculate modules to delete
        let modulesToDelete0 = Map.fromIter<Text, Common.Module>(
            Iter.filter<(Text, Common.Module)>(
                Map.entries(oldPkgReal.modules),
                func (x: (Text, Common.Module)) = Option.isNull(Map.get(newPkgModules, Text.compare, x.0))
            ),
            Text.compare,
        );
        let modulesToDelete = Iter.toArray(
            Iter.filterMap<Text, (Text, Principal)>(
                Map.keys(modulesToDelete0),
                func (name: Text) {
                    let ?m = Map.get(oldPkg.modulesInstalledByDefault, Text.compare, name) else {
                        // throw Error.reject("programming error");
                        return null;
                    };
                    ?(name, m);
                },
            )
        );

        // Calculate all modules (old + new)
        let allModules = Map.fromIter<Text, ()>(
            Iter.map<Text, (Text, ())>(
                Iter.concat(Map.keys(oldPkg.modulesInstalledByDefault), Map.keys(newPkgModules)), func (x: Text) = (x, ())
            ),
            Text.compare,
        );

        let halfUpgradedInfo: HalfUpgradedPackageInfo = {
            installationId;
            package = newPkg;
            newRepo;
            modulesInstalledByDefault = Map.empty();
            modulesToDelete;
            var remainingModules = Map.size(allModules) - modulesToDelete.size(); // modules to install or upgrade
            arg;
            initArg;
        };

        #ok {
            halfUpgradedInfo;
            modulesToDelete;
            allModulesCount = Map.size(allModules);
        };
    };

    public shared({caller}) func installPackages({
        packages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
            arg: Blob;
            initArg: ?Blob;
        }];
        user: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async {minInstallationId: Common.InstallationId}
    {
        switch (onlyOwner(caller, "")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let minInstallationId = nextInstallationId;
        nextInstallationId += packages.size();

        let batteryActor = actor(Principal.toText(battery)) : actor {
            depositCycles: shared (Nat, CyclesLedger.Account) -> async ();
        };
        label l for (p in packages.vals()) {
            let info = await p.repo.getPackage(p.packageName, p.version);
            if (info.base.price != 0) {
                let ?developer = info.base.developer else {
                    // Dishonest to the developer? What else we can do?
                    await batteryActor.depositCycles(
                        info.base.price - Common.cycles_transfer_fee,
                        {owner = Principal.fromText(env.revenueRecipient); subaccount = null},
                    );
                    continue l;
                };
                let revenue = Int.abs(Float.toInt(Float.fromInt(info.base.price) * env.paidAppRevenueShare));
                let developerAmount = info.base.price - revenue;
                await batteryActor.depositCycles(
                    revenue - Common.cycles_transfer_fee,
                    {owner = Principal.fromText(env.revenueRecipient); subaccount = null},
                );
                await batteryActor.depositCycles(developerAmount - Common.cycles_transfer_fee, developer);
            };
        };

        await* _installModulesGroup({ // TODO@P3: Rename this function.
            mainIndirect = getMainIndirect();
            minInstallationId;
            packages = Iter.toArray(Iter.map<
                {
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryRO;
                    arg: Blob;
                    initArg: ?Blob;
                },
                {
                    repo: Common.RepositoryRO;
                    packageName: Common.PackageName;
                    version: Common.Version;
                    arg: Blob;
                    initArg: ?Blob;
                    preinstalledModules: [(Text, Principal)];
                },
            >(packages.vals(), func (p: {
                repo: Common.RepositoryRO;
                packageName: Common.PackageName;
                version: Common.Version;
                arg: Blob;
                initArg: ?Blob;
            }) = {
                repo = p.repo;
                packageName = p.packageName;
                version = p.version;
                arg = p.arg;
                initArg = p.initArg;
                preinstalledModules = [];
            }));
            pmPrincipal = Principal.fromActor(this);
            user;
            afterInstallCallback;
            bootstrapping = false;
        });
    };

    public shared({caller}) func uninstallPackages({
        packages: [Common.InstallationId];
        user: Principal;
    })
        : async {minUninstallationId: Common.UninstallationId}
    {
        switch (onlyOwner(caller, "uninstallPackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let minUninstallationId = nextUninstallationId;
        nextUninstallationId += Array.size(packages);
        var ourNextUninstallationId = minUninstallationId;

        label cycle for (installationId in packages.vals()) {
            let uninstallationId = ourNextUninstallationId;
            ourNextUninstallationId += 1;
            let ?pkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId) else {
                continue cycle; // already uninstalled
            };
            ignore Map.insert(halfUninstalledPackages, Int.compare, uninstallationId, {
                installationId;
                package = pkg.package;
                var remainingModules = Common.numberOfModules(pkg);
            });
            for ((_name, canister_id) in Common.modulesIterator(pkg)) {
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
            arg: Blob;
            initArg: ?Blob;
        }];
        user: Principal;
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    })
        : async {minUpgradeId: Common.UpgradeId}
    {
        switch (onlyOwner(caller, "upgradePackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let batteryActor = actor(Principal.toText(battery)) : actor {
            depositCycles: shared (Nat, CyclesLedger.Account) -> async ();
        };
        label l for (p in packages.vals()) {
            let info = await p.repo.getPackage(p.packageName, p.version);
            if (info.base.upgradePrice != 0) {
                let ?developer = info.base.developer else {
                    await batteryActor.depositCycles(
                        info.base.upgradePrice - Common.cycles_transfer_fee,
                        {owner = Principal.fromText(env.revenueRecipient); subaccount = null},
                    );
                    continue l;
                };
                let revenue = Int.abs(Float.toInt(Float.fromInt(info.base.upgradePrice) * env.paidAppRevenueShare));
                let developerAmount = info.base.upgradePrice - revenue;
                await batteryActor.depositCycles(
                    revenue - Common.cycles_transfer_fee,
                    {owner = Principal.fromText(env.revenueRecipient); subaccount = null},
                );
                await batteryActor.depositCycles(developerAmount - Common.cycles_transfer_fee, developer);
            };
        };

        let minUpgradeId = nextUpgradeId;
        nextUpgradeId += Array.size(packages);

        getMainIndirect().upgradePackageWrapper({
            minUpgradeId;
            packages;
            user;
            afterUpgradeCallback;
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
            arg: Blob;
            initArg: ?Blob;
        }];
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async () {
        switch (onlyOwner(caller, "upgradeStart")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        for (newPkgNum in packages.keys()) {
            let newPkgData = packages[newPkgNum];
            let newPkg = Common.unsharePackageInfo(newPkgData.package); // TODO@P3: Need to unshare the entire variable?
            
            switch (prepareUpgradeData({
                installationId = newPkgData.installationId;
                newPkg;
                newRepo = Principal.fromActor(newPkgData.repo);
                arg = newPkgData.arg;
                initArg = newPkgData.initArg;
            })) {
                case (#ok {halfUpgradedInfo; modulesToDelete; allModulesCount}) {
                    // Debug.print("XXX: " # debug_show(halfUpgradedInfo.remainingModules) # " delete: " # debug_show(modulesToDelete.size()));
                    ignore Map.insert(halfUpgradedPackages, Int.compare, minUpgradeId + newPkgNum, halfUpgradedInfo);
                    await* doUpgradeFinish(minUpgradeId + newPkgNum, halfUpgradedInfo, newPkgData.installationId, user, afterUpgradeCallback); // TODO@P3: Use named arguments.
                };
                case (#err err) {
                    throw Error.reject("Error in upgradeStart: " # err);
                };
            };
        };
    };

    /// Internal
    public shared({caller}) func onUpgradeOrInstallModule({
        upgradeId: Common.UpgradeId;
        moduleName: Text;
        canister_id: Principal;
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async () {
        switch (onlyOwner(caller, "onUpgradeOrInstallModule")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?upgrade = Map.get<Common.UpgradeId, HalfUpgradedPackageInfo>(halfUpgradedPackages, Int.compare, upgradeId) else {
            throw Error.reject("no such upgrade: " # debug_show(upgradeId));
        };
        ignore Map.insert(upgrade.modulesInstalledByDefault, Text.compare, moduleName, canister_id);

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
            };
            let ?inst = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, upgrade.installationId) else {
                throw Error.reject("no such installed package");
            };
            inst.packageRepoCanister := upgrade.newRepo;
            inst.package := upgrade.package;
            inst.modulesInstalledByDefault := upgrade.modulesInstalledByDefault;
            ignore Map.delete(halfUpgradedPackages, Int.compare, upgradeId);
        };

        // Call the user's callback if provided
        let #real real = upgrade.package.specific else {
            throw Error.reject("trying to directly install a virtual package");
        };
        let ?inst = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, upgrade.installationId) else {
            throw Error.reject("no such installed package");
        };
        label r for ((moduleName, module_) in Map.entries(real.modules)) {
            let ?cbPrincipal = Map.get(inst.modulesInstalledByDefault, Text.compare, moduleName) else {
                continue r; // We remove the module in other part of the code.
            };
            switch (Map.get(module_.callbacks, Common.moduleEventCompare, #CodeUpgradedForAllCanisters)) {
                case (?callbackName) {
                    ignore getSimpleIndirect().callAll([{
                        canister = cbPrincipal;
                        name = callbackName.method;
                        data = to_candid({
                            // TODO@P3
                            upgradeId;
                            installationId = upgrade.installationId;
                            packageManager = Principal.fromActor(this);
                        });
                        error = #abort;
                    }]);
                };
                case null {};
            };
        };
        if (upgrade.remainingModules == 0) {
            switch (afterUpgradeCallback) {
                case (?afterUpgradeCallback) {
                    ignore getSimpleIndirect().callAll([{
                        canister = afterUpgradeCallback.canister;
                        name = afterUpgradeCallback.name;
                        data = afterUpgradeCallback.data;
                        error = #abort; // TODO@P3: Here it's superfluous.
                    }]);
                };
                case null {};
            };
            ignore Map.delete(halfInstalledPackages, Int.compare, installationId);
        };
    };

    /// Internal
    public shared({caller}) func onDeleteCanister({
        uninstallationId: Common.UninstallationId;
    }): async () {
        Debug.print("onDeleteCanister");

        switch (onlyOwner(caller, "onDeleteCanister")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?uninst = Map.get<Common.UninstallationId, HalfUninstalledPackageInfo>(halfUninstalledPackages, Int.compare, uninstallationId) else {
            return;
        };
        uninst.remainingModules -= 1;
        if (uninst.remainingModules == 0) {
            let ?pkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, uninst.installationId) else {
                return;
            };
            ignore Map.delete(installedPackages, Nat.compare, uninst.installationId);
            let guid2 = Common.amendedGUID(pkg.package.base.guid, pkg.package.base.name);
            switch (Map.get(installedPackagesByName, Blob.compare, guid2)) {
                case (?info) {
                    if (Map.size(info.all) == 1) {
                        ignore Map.delete(installedPackagesByName, Blob.compare, guid2);
                        info.default := 0;
                    } else {
                        ignore Map.delete(info.all, Nat.compare, uninst.installationId);
                        if (info.default == uninst.installationId) {
                            let ?(last, ()) = Map.reverseEntries(info.all).next() else {
                                throw Error.reject("programming error");
                            };
                            info.default := last;
                        };
                    }
                };
                case null {};
            };
            ignore Map.delete(halfUninstalledPackages, Int.compare, uninstallationId);
        };
    };

    /// Internal used for bootstrapping.
    public shared({caller}) func facilitateBootstrap({
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryRO;
        arg: Blob;
        initArg: ?Blob;
        user: Principal;
        mainIndirect: Principal;
        /// Additional packages to install after bootstrapping.
        preinstalledModules: [(Text, Principal)];
    })
        : async {minInstallationId: Common.InstallationId}
    {
        switch (onlyOwner(caller, "facilitateBootstrap")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let minInstallationId = nextInstallationId;
        nextInstallationId += 1;

        // We first fully install the package manager, and only then other packages.
        ignore await* _installModulesGroup({
            mainIndirect = actor(Principal.toText(mainIndirect));
            minInstallationId;
            packages = [{packageName; version; repo; preinstalledModules; arg; initArg}]; // HACK
            pmPrincipal = Principal.fromActor(this);
            user;
            afterInstallCallback = null;
            bootstrapping = true;
        });

        // let ?battery = coreModules.get("battery") else {
        //     throw Error.reject("error getting battery");
        // };
        {minInstallationId}
    };

    // TODO@P3: Remove?
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
            arg: Blob;
            initArg: ?Blob;
        }];
        bootstrapping: Bool;
    }) {
        switch (onlyOwner(caller, "installStart")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        for (p0 in packages.keys()) {
            let p = packages[p0];
            let #real realPackage = p.package.specific else {
                throw Error.reject("trying to directly install a virtual package");
            };

            let package2 = Common.unsharePackageInfo(p.package); // TODO@P3: why used twice below? seems to be a mis-programming.
            let numModules = realPackage.modules.size();

            let preinstalledModules = Map.fromIter<Text, Principal>(p.preinstalledModules.vals(), Text.compare);

            let ourHalfInstalled: HalfInstalledPackageInfo = {
                package = package2;
                packageRepoCanister = Principal.fromActor(p.repo);
                modulesInstalledByDefault = preinstalledModules;
                minInstallationId;
                afterInstallCallback;
                bootstrapping;
                var remainingModules = numModules;
                arg = p.arg;
                initArg = p.initArg;
            };
            ignore Map.insert(halfInstalledPackages, Int.compare, minInstallationId + p0, ourHalfInstalled);

            await* doInstallFinish(minInstallationId + p0, ourHalfInstalled);
        };
    };

    // TODO@P3: Check that all useful code has been moved from here and delete this function.
    private func doInstallFinish(p0: Common.InstallationId, pkg: HalfInstalledPackageInfo): async* () {
        let p = pkg.package;
        let modules: Iter.Iter<(Text, Common.Module)> =
            switch (p.specific) {
                case (#real pkgReal) {
                    Iter.filter<(Text, Common.Module)>(
                        Map.entries(pkgReal.modules),
                        func (p: (Text, Common.Module)) = p.1.installByDefault,
                    );
                };
                case (#virtual _) [].vals();
            };

        // TODO@P3: `Iter.toArray` is a (small) slowdown.
        let bi = if (pkg.bootstrapping) {
            Iter.toArray(Map.entries(pkg.modulesInstalledByDefault));
        } else {
            let ?pkg0 = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, 0) else {
                throw Error.reject("package manager not installed");
            };
            Iter.toArray(Map.entries(pkg0.modulesInstalledByDefault));
        };
        let coreModules = Map.fromIter<Text, Principal>(bi.vals(), Text.compare);
        var moduleNumber = 0;
        let ?backend = Map.get(coreModules, Text.compare, "backend") else {
            throw Error.reject("error getting backend");
        };
        let ?main_indirect = Map.get(coreModules, Text.compare, "main_indirect") else {
            throw Error.reject("error getting main_indirect");
        };
        let ?simple_indirect = Map.get(coreModules, Text.compare, "simple_indirect") else {
            throw Error.reject("error getting simple_indirect");
        };
        let batteryActor = actor(Principal.toText(battery)) : actor {
            withdrawCycles3: shared (cyclesAmount: Nat, withdrawer: Principal) -> async ();
        };
        if (not pkg.bootstrapping) {
            await batteryActor.withdrawCycles3(
                newCanisterCycles * (switch (p.specific) {
                    case (#real pkgReal) Map.size(pkgReal.modules);
                    case (#virtual _) 0;
                }),
                Principal.fromActor(main_indirect_));
        };
        var i = 0;
        for ((name, m): (Text, Common.Module) in modules) {
            /// TODO@P3: Do one transfer instead of transferring in a loop.
            // Starting installation of all modules in parallel:
            getMainIndirect().installModule({
                moduleNumber;
                moduleName = ?name;
                arg = to_candid({
                    // TODO@P3: Add more arguments.
                    userArg = pkg.arg;
                    pubKey = null;
                });
                installationId = p0;
                packageManager = backend;
                mainIndirect = main_indirect;
                simpleIndirect = simple_indirect;
                preinstalledCanisterId = if (pkg.bootstrapping) { Map.get(coreModules, Text.compare, name) } else { null };
                user;
                wasmModule = Common.shareModule(m); // TODO@P3: We unshared, then shared it, huh?
                afterInstallCallback = pkg.afterInstallCallback;
            });
            // TODO@P3: Do two following variables duplicate each other?
            moduleNumber += 1;
            i += 1;
        };
    };

    private func doUpgradeFinish(
        p0: Common.UpgradeId,
        pkg: HalfUpgradedPackageInfo,
        installationId: Common.InstallationId,
        user: Principal,
        afterUpgradeCallback: ?{
            canister: Principal; name: Text; data: Blob;
        },
    ): async* () {
        var posTmp = 0;
        let #real newPkgReal = pkg.package.specific else {
            throw Error.reject("trying to directly install a virtual package");
        };
        // TODO@P3: upgrading a real package into virtual or vice versa
        let newPkgModules = newPkgReal.modules;

        let batteryActor = actor(Principal.toText(battery)) : actor {
            withdrawCycles3: shared (cyclesAmount: Nat, withdrawer: Principal) -> async ();
        };
        await batteryActor.withdrawCycles3(
            newCanisterCycles * Map.size(newPkgModules) - Array.size(pkg.modulesToDelete),
            Principal.fromActor(main_indirect_));

        // TODO@P3: repeated calculation
        let ?oldPkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, pkg.installationId) else {
            throw Error.reject("no such package installation");
        };
        // let #real oldPkgReal = oldPkg.package.specific else {
        //     throw Error.reject("trying to directly upgrade a virtual package");
        // };
        // let oldPkgModules = oldPkgReal.modules; // Corrected: Use oldPkgReal modules.
        // let oldPkgModulesHash = Map.fromIter<Text, Common.Module>(oldPkgModules.entries(), oldPkgModules.size(), Text.equal, Text.hash);

        for (name in Map.keys(newPkgModules)) {
            let pos = posTmp;
            posTmp += 1;

            let canister_id = Map.get(oldPkg.modulesInstalledByDefault, Text.compare, name);
            let ?wasmModule = Map.get<Text, Common.Module>(newPkgModules, Text.compare, name) else {
                throw Error.reject("programming error: no such module");
            };
            getMainIndirect().upgradeOrInstallModule({
                upgradeId = p0;
                installationId;
                canister_id;
                user;
                wasmModule = Common.shareModule(wasmModule);
                arg = to_candid({
                    packageManager;
                    mainIndirect;
                    simpleIndirect;
                    user;
                    installationId;
                    userArg = pkg.arg;
                    pubKey = null;
                });
                moduleName = name;
                moduleNumber = pos;
                packageManager = Principal.fromActor(this);
                // mainIndirect;
                simpleIndirect;
                afterUpgradeCallback;
            });
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
        packageManager: Principal;
        afterInstallCallback: ?{
            canister: Principal; name: Text; data: Blob;
        };
    }): async () {
        // TODO@P3: Move after `onlyOwner` call:
        Debug.print("Called onInstallCode for canister " # debug_show(canister) # " (" # debug_show(moduleName) # ")");

        switch (onlyOwner(caller, "onInstallCode")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Debug.print("onInstallCode: Cycles accepted: " # debug_show(Cycles.available()));
        ignore Cycles.accept<system>(Cycles.available());

        let ?inst = Map.get<Common.InstallationId, HalfInstalledPackageInfo>(halfInstalledPackages, Nat.compare, installationId) else {
            throw Error.reject("no such package"); // better message
        };
        switch (moduleName) {
            case (?name) {
                ignore Map.insert(inst.modulesInstalledByDefault, Text.compare, name, canister);
            };
            case null {};
        };
        let #real realPackage = inst.package.specific else { // TODO@P3: fails with virtual packages
            throw Error.reject("trying to directly install a virtual installation");
        };
        // Note that we have different algorithms for zero and non-zero number of callbacks (TODO@P3: check).
        inst.remainingModules -= 1;
        if (inst.remainingModules == 0) { // All module have been installed.
            await* _updateAfterInstall({installationId});
            for ((moduleName2, module4) in Map.entries(realPackage.modules)) {
                switch (Map.get(module4.callbacks, Common.moduleEventCompare, #CodeInstalledForAllCanisters)) {
                    case (?callbackName) {
                        let ?cbPrincipal = Map.get(inst.modulesInstalledByDefault, Text.compare, moduleName2) else {
                            throw Error.reject("programming error 3");
                        };
                        ignore getSimpleIndirect().callAll([{
                            canister = cbPrincipal;
                            name = callbackName.method;
                            data = to_candid({
                                // TODO@P3
                                installationId;
                                canister;
                                user;
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
                        error = #abort; // TODO@P3: Here it's superfluous.
                    }]);
                };
                case null {};
            };
            ignore Map.delete(halfInstalledPackages, Int.compare, installationId);
        };
    };

    private func _updateAfterInstall({installationId: Common.InstallationId}): async* () {
        let ?ourHalfInstalled = Map.get<Common.InstallationId, HalfInstalledPackageInfo>(halfInstalledPackages, Nat.compare, installationId) else {
            throw Error.reject("package installation has not been started");
        };
        // let pubKey : ?Blob = null;
        ignore Map.insert<Nat, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId, {
            id = installationId;
            var package = ourHalfInstalled.package;
            var packageRepoCanister = ourHalfInstalled.packageRepoCanister;
            var modulesInstalledByDefault = ourHalfInstalled.modulesInstalledByDefault; // no need for deep copy, because we delete `ourHalfInstalled` soon
            additionalModules = Map.empty<Text, List.List<Principal>>();
            var pubKey = null;
            var pinned = false;
        });
        let guid2 = Common.amendedGUID(ourHalfInstalled.package.base.guid, ourHalfInstalled.package.base.name);
        let tree = switch (Map.get<Blob, {all: Map.Map<Common.InstallationId, ()>; var default: Common.InstallationId}>(installedPackagesByName, Blob.compare, guid2)) {
            case (?old) {
                old.all;
            };
            case null {
                let tree = Map.empty<Common.InstallationId, ()>();
                ignore Map.insert(installedPackagesByName, Blob.compare, guid2, {
                    all = tree;
                    var default = installationId;
                });
                tree;
            };
        };
        ignore Map.insert(tree, Nat.compare, installationId, ());
    };

    //     let ?installation = installedPackages.get(installationId) else {
    //         throw Error.reject("no such installed installation");
    //     };
    //     let part: repository.repository = actor (Principal.toText(installation.packageRepoCanister));
    //     let packageInfo = await part.getPackage(installation.name, installation.version);

    //     let ourHalfInstalled: HalfInstalledPackageInfo = {
    //         numberOfModulesToInstall = installation.modules.size();
    //         name = installation.name;
    //         version = installation.version;
    //         modules = Map.fromIter<Text, (Principal, {#empty; #installed})>(
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
    //         preinstalledModules = null;
    //     };
    //     halfInstalledPackages.put(installationId, ourHalfInstalled);

    //     // let part: Common.RepositoryRO = actor (Principal.toText(canister));
    //     // let installation = await part.getPackage(packageName, version);
    //     let #real realPackage = packageInfo.specific else {
    //         throw Error.reject("trying to directly install a virtual installation");
    //     };

    //     await* _finishUninstallPackage({
    //         installationId;
    //         ourHalfInstalled;
    //         realPackage;
    //     });
    // };

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
    //         throw Error.reject("programming error: can't get package by name");
    //     };
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

    // Accessor method //

    // TODO@P3: needed?
    /// Returns all (default installed and additional) modules canisters.
    /// Internal.
    public query({caller}) func getAllCanisters(): async [({packageName: Text; guid: Blob}, [(Text, Principal)])] {
        switch (onlyOwner(caller, "getAllCanisters")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Iter.toArray(Iter.map<Common.InstalledPackageInfo, ({packageName: Text; guid: Blob}, [(Text, Principal)])>(
            Map.values(installedPackages),
            func (pkg: Common.InstalledPackageInfo) =
                (
                    {packageName = pkg.package.base.name; guid = pkg.package.base.guid}, 
                    Iter.toArray(Common.modulesIterator(pkg)),
                ),
        ));
    };

    public query({caller}) func getInstalledPackage(id: Common.InstallationId): async Common.SharedInstalledPackageInfo {
        switch (onlyOwner(caller, "getInstalledPackage")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?result = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, id) else {
            throw Error.reject("no such installed package");
        };
        Common.installedPackageInfoShare(result);
    };

    /// Note that it applies only to default installed modules and fails for additional modules.
    public query({caller}) func getModulePrincipal(installationId: Common.InstallationId, moduleName: Text): async Principal {
        switch (onlyOwner(caller, "getModulePrincipal")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?inst = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId) else {
            throw Error.reject("no such installation");
        };
        let ?m = Map.get(inst.modulesInstalledByDefault, Text.compare, moduleName) else {
            throw Error.reject("no such module");
        };
        m;
    };

    public query({caller}) func getInstalledPackagesInfoByName(name: Text, guid: Blob)
        : async {all: [Common.SharedInstalledPackageInfo]; default: Common.InstallationId}
    {
        switch (onlyOwner(caller, "getInstalledPackagesInfoByName")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let guid2 = Common.amendedGUID(guid, name);
        let ?data = Map.get<Blob, {all: Map.Map<Common.InstallationId, ()>; var default: Common.InstallationId}>(installedPackagesByName, Blob.compare, guid2) else {
            return {all = []; default = 0};
        };
        let all = Iter.toArray(Iter.filterMap<(Common.InstallationId, ()), Common.SharedInstalledPackageInfo>(
            Map.entries(data.all),
            func (id: Common.InstallationId, _: ()): ?Common.SharedInstalledPackageInfo {
                let ?info = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, id) else {
                    // throw Error.reject("getInstalledPackagesInfoByName: programming error");
                    return null;
                };
                ?(Common.installedPackageInfoShare(info));
            }));
        {all; default = data.default};
    };

    public query({caller}) func getAllInstalledPackages(): async [(Common.InstallationId, Common.SharedInstalledPackageInfo)] {
        switch (onlyOwner(caller, "getAllInstalledPackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(
                Map.entries(installedPackages),
                func (info: (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) =
                    (info.0, Common.installedPackageInfoShare(info.1))
            )
        );
    };

    /// Get public key associated with an installation.
    public query({caller}) func getInstallationPubKey(id: Common.InstallationId): async ?Blob {
        switch (Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, id)) {
            case (?info) info.pubKey;
            case null null;
        };
    };

    /// Update public key for an installation.
    public shared({caller}) func setInstallationPubKey(id: Common.InstallationId, pubKey: Blob): async () {
        switch (onlyOwner(caller, "setInstallationPubKey")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?info = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, id) else {
            throw Error.reject("no such installation");
        };
        info.pubKey := ?pubKey;
    };

    /// Internal.
    public query({caller}) func getHalfInstalledPackages(): async [{
        installationId: Common.InstallationId;
        package: Common.SharedPackageInfo;
    }] {
        switch (onlyOwner(caller, "getHalfInstalledPackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Iter.toArray(Iter.map<(Common.InstallationId, HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            package: Common.SharedPackageInfo;
        }>(Map.entries(halfInstalledPackages), func (x: (Common.InstallationId, HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            package: Common.SharedPackageInfo;
        } =
            {
                installationId = x.0;
                package = Common.sharePackageInfo(x.1.package);
            },
        ));
    };

    /// Internal.
    public query({caller}) func getHalfUninstalledPackages(): async [{
        uninstallationId: Common.UninstallationId;
        package: Common.SharedPackageInfo;
    }] {
        switch (onlyOwner(caller, "getHalfUninstalledPackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Iter.toArray(Iter.map<(Common.UninstallationId, HalfUninstalledPackageInfo), {
            uninstallationId: Common.UninstallationId;
            package: Common.SharedPackageInfo;
        }>(Map.entries(halfUninstalledPackages), func (x: (Common.UninstallationId, HalfUninstalledPackageInfo)): {
            uninstallationId: Common.UninstallationId;
            package: Common.SharedPackageInfo;
        } =
            {
                uninstallationId = x.0;
                package = Common.sharePackageInfo(x.1.package);
            },
        ));
    };

    /// Internal.
    public query({caller}) func getHalfUpgradedPackages(): async [{
        upgradeId: Common.UpgradeId;
        package: Common.SharedPackageInfo;
    }] {
        switch (onlyOwner(caller, "getHalfUpgradedPackages")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        Iter.toArray(Iter.map<(Common.UpgradeId, HalfUpgradedPackageInfo), {
            upgradeId: Common.UpgradeId;
            package: Common.SharedPackageInfo;
        }>(Map.entries(halfUpgradedPackages), func (x: (Common.UpgradeId, HalfUpgradedPackageInfo)): {
            upgradeId: Common.UpgradeId;
            package: Common.SharedPackageInfo;
        } =
            {
                upgradeId = x.0;
                package = Common.sharePackageInfo(x.1.package);
            },
        ));
    };

    /// TODO@P3: very unstable API.
    public query({caller}) func getHalfInstalledPackageModulesById(installationId: Common.InstallationId): async [(Text, Principal)] {
        switch (onlyOwner(caller, "getHalfInstalledPackageModulesById")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?res = Map.get<Common.InstallationId, HalfInstalledPackageInfo>(halfInstalledPackages, Int.compare, installationId) else {
            throw Error.reject("no such package");
        };
        // TODO@P3: May be a little bit slow.
        Iter.toArray<(Text, Principal)>(Map.entries(res.modulesInstalledByDefault));
    };

    // TODO@P3: Rearrage functions, possible rename:
    private func _installModulesGroup({
        mainIndirect: MainIndirect.MainIndirect;
        minInstallationId: Common.InstallationId;
        packages: [{
            repo: Common.RepositoryRO;
            packageName: Common.PackageName;
            version: Common.Version;
            preinstalledModules: [(Text, Principal)];
            arg: Blob;
            initArg: ?Blob;
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
        // Cycles are passed to `main_indirect` in other place of the code.
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

    public shared({caller}) func setPinned(installationId: Common.InstallationId, pinned: Bool): async () {
        switch (onlyOwner(caller, "setPinned")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?inst = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, installationId) else {
            throw Error.reject("no such installed package");
        };
        inst.pinned := pinned;
    };

    public shared({caller}) func removeStalled(
        {install: [Common.InstallationId]; uninstall: [Common.UninstallationId]; upgrade: [Common.UpgradeId]}
    ): async () {
        switch (onlyOwner(caller, "removeStalled")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        for (i in install.vals()) {
            ignore Map.delete(halfInstalledPackages, Int.compare, i);
        };
        for (i in uninstall.vals()) {
            ignore Map.delete(halfUninstalledPackages, Int.compare, i);
        };
        for (i in upgrade.vals()) {
            ignore Map.delete(halfUpgradedPackages, Int.compare, i);
        };
    };

    // TODO@P3: Should be in the frontend.
    public query({caller}) func userAccountText(): async Principal { // TODO@P3: wrong value for this wrong type
        battery;
    };

    // private func userAccount(/*user: Principal*/): CyclesLedger.Account {
    //     {owner = battery; subaccount = null/*?(Principal.toBlob(user))*/};
    // };

    public composite query/*({caller})*/ func userBalance(): async Nat {
        await batteryActor.balance();
        // /// because `icrc1_balance_of` does not work on local net as it should.
        // await CyclesLedger.icrc1_balance_of(userAccount(/*caller*/));
    };

    // Adjustable values //

    // TODO@P3: a way to set.

    /// The total cycles amount, including canister creation fee.
    transient let newCanisterCycles = 1_500_000_000_000 * env.subnetSize / 13; // TODO@P3
    /// The total cycles amount, including canister creation fee.
    public query({caller}) func getNewCanisterCycles(): async Nat {
        switch (onlyOwner(caller, "getNewCanisterCycles")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        newCanisterCycles;
    };

    // Convenience methods //

    public shared({caller}) func addRepository(canister: Principal, name: Text): async () {
        switch (onlyOwner(caller, "addRepository")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        repositories := Array.concat(repositories, [{canister; name}]);
    };

    public shared({caller}) func removeRepository(canister: Principal): async () {
        switch (onlyOwner(caller, "removeRepository")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        repositories := Iter.toArray(Iter.filter(
            repositories.vals(),
            func (x: {canister: Principal; name: Text}): Bool = x.canister != canister));
    };

    public query({caller}) func getRepositories(): async [{canister: Principal; name: Text}] {
        switch (onlyOwner(caller, "getRepositories")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        repositories;
    };

    public shared({caller}) func setDefaultInstalledPackage(name: Common.PackageName, guid: Blob, installationId: Common.InstallationId): async () {
        switch (onlyOwner(caller, "setDefaultInstalledPackage")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let guid2 = Common.amendedGUID(guid, name);
        let ?data = Map.get<Blob, {
            all: Map.Map<Common.InstallationId, ()>; // FIXME@P1: `Set`
            var default: Common.InstallationId;
        }>(installedPackagesByName, Blob.compare, guid2) else {
            throw Error.reject("no such package");
        };
        data.default := installationId;
    };

    public shared({caller}) func withdrawCycles(amount: Nat, payee: Principal) : async () {
        await* LIB.withdrawCycles(CyclesLedger, amount, payee, caller);
    };

    /// Copy assets from one canister to another if the module contains assets
    /// wrapper around Install.copyAssetsIfAny from install.mo
    public shared({caller}) func copyAssetsIfAny({
        wasmModule: Common.SharedModule;
        canister_id: Principal;
        simpleIndirect: Principal;
        mainIndirect: Principal;
        user: Principal;
    }): async () {
        switch (onlyOwner(caller, "copyAssetsIfAny")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        await* Install.copyAssetsIfAny({
            wasmModule = Common.unshareModule(wasmModule);
            canister_id;
            simpleIndirect;
            mainIndirect;
            user;
        });
    };

    /// New API for step-by-step upgrades
    /// Initiates an upgrade process and returns upgrade information
    public shared({caller}) func startModularUpgrade({
        installationId: Common.InstallationId;
        packageName: Common.PackageName;
        version: Common.Version;
        repo: Common.RepositoryRO;
        arg: Blob;
        initArg: ?Blob;
        user: Principal;
    })
        : async {
            upgradeId: Common.UpgradeId;
            totalModules: Nat;
            modulesToUpgradeOrInstall: [Text];
            modulesToDelete: [(Text, Principal)];
        }
    {
        switch (onlyOwner(caller, "startModularUpgrade")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        // Get package info from repository first
        let newPkg = Common.unsharePackageInfo(await repo.getPackage(packageName, version));
        
        // Extract modules for cycles calculation
        let #real newPkgReal = newPkg.specific else {
            throw Error.reject("trying to directly upgrade a virtual package");
        };

        let upgradeId = nextUpgradeId;
        nextUpgradeId += 1;
        
        switch (prepareUpgradeData({
            installationId;
            newPkg;
            newRepo = Principal.fromActor(repo);
            arg;
            initArg;
        })) {
            case (#ok {halfUpgradedInfo; modulesToDelete; allModulesCount}) {
                ignore Map.insert(halfUpgradedPackages, Int.compare, upgradeId, halfUpgradedInfo);

                let modulesToDeleteSet = Map.fromIter<Text, ()>(
                    Iter.map<(Text, Principal), (Text, ())>(
                        modulesToDelete.vals(),
                        func ((name: Text, _principal: Principal)) = (name, ()),
                    ),
                    Text.compare,
                );

                let modulesToUpgradeOrInstall = Iter.toArray(
                    Iter.filter<Text>(
                        Map.keys(newPkgReal.modules),
                        func (name: Text) = Option.isNull(Map.get(modulesToDeleteSet, Text.compare, name)),
                    )
                );

                {
                    upgradeId;
                    totalModules = halfUpgradedInfo.remainingModules;
                    modulesToUpgradeOrInstall;
                    modulesToDelete;
                };
            };
            case (#err err) {
                throw Error.reject("Error in startModularUpgrade: " # err);
            };
        };
        
    };

    /// Upgrade a specific module as part of modular upgrade
    public shared({caller}) func upgradeModule({
        upgradeId: Common.UpgradeId;
        moduleName: Text;
        user: Principal;
    }): async {completed: Bool} {
        switch (onlyOwner(caller, "upgradeModule")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?upgrade = Map.get<Common.UpgradeId, HalfUpgradedPackageInfo>(halfUpgradedPackages, Int.compare, upgradeId) else {
            throw Error.reject("no such upgrade: " # debug_show(upgradeId));
        };

        let #real newPkgReal = upgrade.package.specific else {
            throw Error.reject("trying to directly upgrade a virtual package");
        };
        let newPkgModules = newPkgReal.modules;

        let ?wasmModule = Map.get(newPkgModules, Text.compare, moduleName) else {
            throw Error.reject("no such module: " # moduleName);
        };

        // Get the old package info
        let ?oldPkg = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, upgrade.installationId) else {
            throw Error.reject("no such package installation");
        };

        let canister_id = Map.get(oldPkg.modulesInstalledByDefault, Text.compare, moduleName);

        // Upgrade the module using main_indirect
        getMainIndirect().upgradeOrInstallModule({
            upgradeId;
            installationId = upgrade.installationId;
            canister_id;
            user;
            wasmModule = Common.shareModule(wasmModule);
            arg = to_candid({
                packageManager = Principal.fromActor(this);
                mainIndirect = Principal.fromActor(getMainIndirect());
                simpleIndirect = Principal.fromActor(getSimpleIndirect());
                battery;
                user;
                installationId = upgrade.installationId;
                userArg = upgrade.arg;
            });
            moduleName;
            moduleNumber = 0; // Not used for individual upgrades
            packageManager = Principal.fromActor(this);
            simpleIndirect = Principal.fromActor(getSimpleIndirect());
            afterUpgradeCallback = null;
        });

        {completed = false}; // Will be updated via onUpgradeOrInstallModule callback
    };

    /// Get the current status of a modular upgrade
    public query({caller}) func getModularUpgradeStatus(upgradeId: Common.UpgradeId): async {
        upgradeId: Common.UpgradeId;
        installationId: Common.InstallationId;
        packageName: Text;
        completedModules: Nat;
        totalModules: Nat;
        remainingModules: Nat;
        isCompleted: Bool;
    } {
        switch (onlyOwner(caller, "getModularUpgradeStatus")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?upgrade = Map.get<Common.UpgradeId, HalfUpgradedPackageInfo>(halfUpgradedPackages, Int.compare, upgradeId) else {
            throw Error.reject("no such upgrade: " # debug_show(upgradeId));
        };

        let #real newPkgReal = upgrade.package.specific else {
            throw Error.reject("trying to directly upgrade a virtual package");
        };
        let totalModules = Map.size(newPkgReal.modules);
        let completedModules = totalModules - upgrade.remainingModules;

        {
            upgradeId;
            installationId = upgrade.installationId;
            packageName = upgrade.package.base.name;
            completedModules;
            totalModules;
            remainingModules = upgrade.remainingModules;
            isCompleted = upgrade.remainingModules == 0;
        };
    };

    /// Mark all modules as upgraded for a modular upgrade (used for frontend-driven upgrades)
    public shared({caller}) func completeModularUpgrade(
        upgradeId: Common.UpgradeId,
        modules: [(Text, Principal)]
    ): async () {
        switch (onlyOwner(caller, "completeModularUpgrade")) {
            case (#err err) {
                throw Error.reject(err);
            };
            case (#ok) {};
        };

        let ?upgrade = Map.get<Common.UpgradeId, HalfUpgradedPackageInfo>(halfUpgradedPackages, Int.compare, upgradeId) else {
            throw Error.reject("no such upgrade: " # debug_show(upgradeId));
        };
        let ?inst = Map.get<Common.InstallationId, Common.InstalledPackageInfo>(installedPackages, Nat.compare, upgrade.installationId) else {
            throw Error.reject("no such installed package for upgrade: " # debug_show(upgrade.installationId));
        };

        // Update package info
        inst.packageRepoCanister := upgrade.newRepo;
        inst.package := upgrade.package;
        
        // Update modules map - keep only the modules that were successfully upgraded/installed
        inst.modulesInstalledByDefault := Map.fromIter(modules.vals(), Text.compare);
        
        // Clean up
        ignore Map.delete(halfUpgradedPackages, Int.compare, upgradeId);
    }
}