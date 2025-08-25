import Principal "mo:core/Principal";
import Iter "mo:core/Iter";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Types "mo:core/Types";
import List "mo:core/List";
import Map "mo:core/Map";
import Int "mo:core/Int";
import Nat32 "mo:core/Nat32";
import Nat "mo:core/Nat";
import Blob "mo:core/Blob";
import Nat8 "mo:core/Nat8";
import Sha256 "mo:sha2/Sha256";
import Itertools "mo:itertools/Iter";
import Account "lib/Account";
import CyclesLedger "canister:cycles_ledger";

module {
    public type PackageName = Text;

    // TODO@P1: Remove it and use text for Git hashes, etc.?
    // Can be like `6.8.4` or like `stable`, `unstable`, `prerelease`.
    public type Version = Text;

    // TODO@P1: Remove it?
    public type VersionRange = (Version, Version);

    /// Common properties of package and virtual package.
    public type CommonPackageInfo = {
        guid: Blob;
        name: PackageName;
        version: Version;
        price: Nat;
        upgradePrice: Nat;
        shortDescription: Text;
        longDescription: Text;
        developer: ?CyclesLedger.Account;
    };

    public type Location = (canister: Principal, id: Blob); // `id` is a 128-bit hash of the module code.

    public type ModuleEvent = {
        #CodeInstalledForAllCanisters;
        #CodeUpgradedForAllCanisters;
        #WithdrawCycles;
    };

    /// Shared/query method name.
    public type MethodName = {method: Text};

    // `L` may be `Location` or `Blob`.
    public type ModuleCodeBase<L> = {
        #Wasm : L;
        #Assets : {
            wasm: L;
            assets: Principal;
        };
    };

    type ModuleCode = ModuleCodeBase<Location>;

    public type SharedModuleBase<L> = {
        code: ModuleCodeBase<L>;
        installByDefault: Bool;
        forceReinstall: Bool;
        canisterVersion: ?Nat64; // sender_canister_version
        callbacks: [(ModuleEvent, MethodName)];
    };

    public type SharedModule = SharedModuleBase<Location>;

    // TODO@P2: Ensure that functions receive args without template parameters (for conversion to TypeScript).
    // TODO@P3: Remove unnecessary types.
    public type ModuleBase<L> = {
        code: ModuleCodeBase<L>;
        installByDefault: Bool;
        forceReinstall: Bool; // used with such canisters as `MainIndirect`.
        canisterVersion: ?Nat64; // sender_canister_version
        callbacks: Map.Map<ModuleEvent, MethodName>;
    };

    public type Module = ModuleBase<Location>;

    public type IndexedPackageInfo = {
        serial: Nat;
        package: PackageInfo;
    };

    // Remark: There can be same named real package and a virtual package (of different versions).
    public type FullPackageInfo = {
        listByVersion: List.List<IndexedPackageInfo>;
        versionsMap: Map.Map<Version, IndexedPackageInfo>;
    };

    // Probably, not very efficient.
    public func amendedGUID(guid: Blob, name: PackageName): Blob {
        let b = Array.empty<Nat8>();
        let b1 = Array.concat(b, Blob.toArray(guid));
        let b2 = Array.concat(b1, Blob.toArray(Text.encodeUtf8(name)));
        let h256 = Sha256.fromArray(#sha256, b2);
        Blob.fromArray(Array.sliceToArray<Nat8>(Blob.toArray(h256), 0, 16)); // 128-bit hash
    };

    public func moduleEventToNat(e: ModuleEvent): Nat {
        switch (e) {
            case (#CodeInstalledForAllCanisters) 0;
            case (#CodeUpgradedForAllCanisters) 1;
            case (#WithdrawCycles) 2;
        };
    };

    public func moduleEventCompare(a: ModuleEvent, b: ModuleEvent): Types.Order {
        Nat.compare(moduleEventToNat(a), moduleEventToNat(b));
    };

    public func shareModule<L>(m: ModuleBase<L>): SharedModuleBase<L> =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
            canisterVersion = m.canisterVersion;
            callbacks = Iter.toArray(Map.entries<ModuleEvent, MethodName>(m.callbacks));
        };

    public func unshareModule<L>(m: SharedModuleBase<L>): ModuleBase<L> =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
            canisterVersion = m.canisterVersion;
            callbacks = Map.fromIter(m.callbacks.vals(), moduleEventCompare);
        };

    public type ModuleUploadCode = ModuleCodeBase<Blob>;

    public type ModuleUpload = SharedModuleBase<Blob>;

    /// If `how` is `#methodName`, then the module is considered initialized when
    /// the method is called and doesn't trap.
    /// If `how` is `#urlPath`, then the module is considered initialized when
    /// the URL path (starting with `/`) exists.
    public type CheckInitializedCallback = {
        moduleName: Text;
        how: {
            #methodName : Text;
            #urlPath : Text;
        };
    };

    public type SharedRealPackageInfoBase<L> = {
        modules: [(Text, SharedModuleBase<L>)]; // Modules are named for correct upgrades.
        dependencies: [(PackageName, ?[VersionRange])];
        suggests: [(PackageName, ?[VersionRange])];
        recommends: [(PackageName, ?[VersionRange])];
        functions: [(PackageName, ?[VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    /// See `RealPackageInfoBase`.
    public type SharedRealPackageInfo = SharedRealPackageInfoBase<Location>;

    /// `dependencies`, `suggests`, `recommends` (akin Debian) are currently not supported.
    /// Package's `functions` (currently not supported) are unrelated to Motoko functions.
    /// `modules` are named canisters. (Names are needed for example to know which module should be
    /// replaced by which during an upgrade.)
    public type RealPackageInfoBase<L> = {
        modules: Map.Map<Text, ModuleBase<L>>; // Modules are named for correct upgrades. `Bool` means "install by default".
        dependencies: [(PackageName, ?[VersionRange])];
        suggests: [(PackageName, ?[VersionRange])];
        recommends: [(PackageName, ?[VersionRange])];
        functions: [(PackageName, ?[VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    public type RealPackageInfo = RealPackageInfoBase<Location>;

    public type SharedPackageInfoBase<L> = {
        base: CommonPackageInfo;
        specific: {
            #real : SharedRealPackageInfoBase<L>;
            #virtual : VirtualPackageInfo;
        };
    };

    public type SharedPackageInfo = SharedPackageInfoBase<Location>;

    /// See `RealPackageInfoBase`.
    public type RealSharedPackageInfoTemplate = SharedRealPackageInfoBase<None>;

    public type SharedPackageInfoTemplate = SharedPackageInfoBase<None>;

    /// Yet unsupported.
    public type VirtualPackageInfo = {
        choice: [(PackageName, ?[VersionRange])];
        default: PackageName;
    };

    public type PackageInfoBase<L> = {
        base: CommonPackageInfo;
        specific: {
            #real : RealPackageInfoBase<L>;
            #virtual : VirtualPackageInfo;
        };
    };

    public type PackageInfo = PackageInfoBase<Location>;

    public func shareRealPackageInfo(package: RealPackageInfoBase<Location>): SharedRealPackageInfoBase<Location> =
        {
            modules = Iter.toArray(
                Iter.map<(Text, ModuleBase<Location>), (Text, SharedModuleBase<Location>)>(
                    Map.entries(package.modules),
                    func ((k, m): (Text, ModuleBase<Location>)): (Text, SharedModuleBase<Location>) = (k, shareModule(m)),
                ),
            );
            dependencies = package.dependencies;
            suggests = package.suggests;
            recommends = package.recommends;
            functions = package.functions;
            permissions = package.permissions;
            checkInitializedCallback = package.checkInitializedCallback;
            frontendModule = package.frontendModule;
        };

    public func unshareRealPackageInfo(package: SharedRealPackageInfoBase<Location>): RealPackageInfoBase<Location> =
        {
            modules = Map.fromIter(
                Iter.map<(Text, SharedModuleBase<Location>), (Text, ModuleBase<Location>)>(
                    package.modules.vals(),
                    func ((k, m): (Text, SharedModuleBase<Location>)): (Text, ModuleBase<Location>) = (k, unshareModule(m)),
                ),
                Text.compare,
            );
            dependencies = package.dependencies;
            suggests = package.suggests;
            recommends = package.recommends;
            functions = package.functions;
            permissions = package.permissions;
            checkInitializedCallback = package.checkInitializedCallback;
            frontendModule = package.frontendModule;
        };

    // TODO@P3: Use non-shared package info template for more efficiency and simplicity.
    // FIXME@P1: Fix this function.
    // FIXME@P1: Need to upload?
    private func fillRealPackageInfoTemplate(template: RealSharedPackageInfoTemplate, modules: [(Text, SharedModule)]): RealPackageInfo =
        {
            modules = Map.fromIter<Text, Module>( // FIXME@P1: `Location` is not `Blob`   .
                Iter.map<(Text, SharedModule), (Text, Module)>(modules.vals(),
                func ((k, v): (Text, SharedModule)): (Text, Module) = (k, unshareModule(v))),
                Text.compare,
            );
            dependencies = template.dependencies;
            suggests = template.suggests;
            recommends = template.recommends;
            functions = template.functions;
            permissions = template.permissions;
            checkInitializedCallback = template.checkInitializedCallback;
            frontendModule = template.frontendModule;
        };

    public func fillPackageInfoTemplate(template: SharedPackageInfoTemplate, modules: [(Text, SharedModule)]): PackageInfo =
        {
            base = template.base;
            specific = switch (template.specific) {
                case (#real x) #real(fillRealPackageInfoTemplate(x, modules));
                case (#virtual x) #virtual x;
            };
        };

    public func sharePackageInfo(info: PackageInfo): SharedPackageInfo =
        {
            base = info.base;
            specific = switch (info.specific) {
                case (#real x) { #real (shareRealPackageInfo(x)); };
                case (#virtual x) { #virtual x; };
            }
        };

    public func unsharePackageInfo(info: SharedPackageInfo): PackageInfo =
        {
            base = info.base;
            specific = switch (info.specific) {
                case (#real x) { #real (unshareRealPackageInfo(x)); };
                case (#virtual x) { #virtual x; };
            }
        };

    // public type SharedHalfInstalledPackageInfo = {
    //     packageName: Text;
    //     version: Version;
    //     package: SharedPackageInfo;
    // };

    public type InstallationId = Nat;
    public type UninstallationId = Nat;
    public type UpgradeId = Nat;

    public type RepositoryRO = actor {
        getRepositoryName: query () -> async Text;
        getRepositoryInfoURL: query () -> async Text;
        /// Returns releases with optional other release name
        /// (like `("stable", ?"morpheus")`).
        getReleases: query () -> async [(Text, ?Text)];
        getPackage: query (name: PackageName, version: Version) -> async SharedPackageInfo;
        getWasmModule: query (sk: Blob) -> async Blob;
    };

    public type InstalledPackageInfo = {
        id: InstallationId;
        var package: PackageInfo;
        var packageRepoCanister: Principal;
        var modulesInstalledByDefault: Map.Map<Text, Principal>;
        additionalModules: Map.Map<Text, List.List<Principal>>;
        /// Public key used to verify configuration requests for this installation.
        var pubKey: ?Blob;
        var pinned: Bool;
    };

    public type SharedInstalledPackageInfo = {
        id: InstallationId;
        package: SharedPackageInfo;
        packageRepoCanister: Principal;
        modulesInstalledByDefault: [(Text, Principal)];
        additionalModules: [(Text, [Principal])];
        pubKey: ?Blob;
        pinned: Bool;
    };

    private func additionalModulesIter(additionalModules: Map.Map<Text, List.List<Principal>>)
        : Iter.Iter<(Text, Principal)>
    {
        Itertools.flatten(
            Iter.map<(Text, List.List<Principal>), Iter.Iter<(Text, Principal)>>(
                Map.entries(additionalModules),
                // TODO@P3: Use standard functions rather that `Itertools`.
                func ((name, buf): (Text, List.List<Principal>)) = Itertools.zip(Iter.infinite(name), List.values(buf)),
            ),
        );
    };

    // Tested in `modulesIter.test.mo`.
    /// Iterate over all modules in `pkg.namedModules`.
    public func modulesIterator(pkg: InstalledPackageInfo): Iter.Iter<(Text, Principal)> {
        Iter.concat(Map.entries(pkg.modulesInstalledByDefault), additionalModulesIter(pkg.additionalModules));
    };

    public func numberOfModules(pkg: InstalledPackageInfo): Nat {
        Map.size(pkg.modulesInstalledByDefault) + Iter.size(additionalModulesIter(pkg.additionalModules));
    };

    public func installedPackageInfoShare(info: InstalledPackageInfo): SharedInstalledPackageInfo = {
        id = info.id;
        package = sharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        modulesInstalledByDefault = Iter.toArray(Map.entries(info.modulesInstalledByDefault));
        additionalModules = Iter.toArray(
            Iter.map<(Text, List.List<Principal>), (Text, [Principal])>(
                Map.entries(info.additionalModules),
                func ((k, v): (Text, List.List<Principal>)): (Text, [Principal]) = (k, List.toArray(v))
            )
        );
        pubKey = info.pubKey;
        pinned = info.pinned;
    };

    public func installedPackageInfoUnshare(info: SharedInstalledPackageInfo): InstalledPackageInfo = {
        id = info.id;
        var package = unsharePackageInfo(info.package);
        var packageRepoCanister = info.packageRepoCanister;
        var modulesInstalledByDefault = Map.fromIter(
            info.modulesInstalledByDefault.vals(),
            Text.compare,
        );
        additionalModules = Map.fromIter(
            Iter.map<(Text, [Principal]), (Text, List.List<Principal>)>(
                info.additionalModules.vals(),
                func ((k, v): (Text, [Principal])): (Text, List.List<Principal>) = (k, List.fromArray(v))
            ),
            Text.compare,
        );
        var pubKey = info.pubKey;
        var pinned = info.pinned;
    };

    // Remark: There can be same named real package and a virtual package (of different versions).
    public type SharedFullPackageInfo = {
        listByVersion: [SharedPackageInfo]; // Pass version instead as a part of package?
        versionsMap: [(Version, Nat)]; // position in `listByVersion`
    };

    public func shareFullPackageInfo(info: FullPackageInfo): SharedFullPackageInfo =
        {
            listByVersion = Iter.toArray(
                Iter.map<PackageInfo, SharedPackageInfo>(
                    Iter.map<IndexedPackageInfo, PackageInfo>(List.values(info.listByVersion), func (p: IndexedPackageInfo): PackageInfo = p.package),
                    func (i: PackageInfo): SharedPackageInfo = sharePackageInfo(i),
                ),
            );
            versionsMap = Iter.toArray(Iter.map<(Version, IndexedPackageInfo), (Version, Nat)>(
                Map.entries<Version, IndexedPackageInfo>(info.versionsMap),
                func (p: (Version, IndexedPackageInfo)): (Version, Nat) = (p.0, p.1.serial)),
            );
        };

    public func unshareFullPackageInfo(info: SharedFullPackageInfo): FullPackageInfo {
        let listByVersion = List.fromArray<IndexedPackageInfo>(Array.fromIter<IndexedPackageInfo>(
                Iter.map<(Nat, SharedPackageInfo), IndexedPackageInfo>(
                    Iter.enumerate<SharedPackageInfo>(
                        info.listByVersion.vals(),
                    ),
                    func (p: (Nat, SharedPackageInfo)): IndexedPackageInfo = {serial = p.0; package = unsharePackageInfo(p.1)},
                ),
            ));
        {
            listByVersion;
            versionsMap = Map.fromIter(
                Iter.map<(Version, Nat), (Version, IndexedPackageInfo)>(
                    info.versionsMap.vals(),
                    func (p: (Version, Nat)): (Version, IndexedPackageInfo) {
                        let pkg = info.listByVersion[p.1];
                        (p.0, {serial = p.1; package = unsharePackageInfo(pkg)})
                    }
                ),
                Text.compare,
            );
        };
    };

    public func extractModuleLocation(code: ModuleCodeBase<Location>): (Principal, Blob) =
        switch (code) {
            case (#Wasm wasmModuleLocation) {
                wasmModuleLocation;
            };
            case (#Assets {wasm}) {
                wasm;
            };
        };

    public func extractModuleUploadBlob(code: ModuleUploadCode): Blob =
        switch (code) {
            case (#Wasm wasm) {
                wasm;
            };
            case (#Assets {wasm}) {
                wasm;
            };
        };

    public type CanisterFulfillment = {
        threshold: Nat;
        topupAmount: Nat;
    };

    public func principalToSubaccount(principal : Principal) : Blob {
        var sub = List.empty<Nat8>();
        let subaccount_blob = Principal.toBlob(principal);

        List.add(sub, Nat8.fromNat(subaccount_blob.size()));
        // List.append(sub, List.fromArray<Nat8>(Blob.toArray(subaccount_blob)));
        for (b in Blob.toArray(subaccount_blob).vals()) { // TODO@P3: inefficient
            List.add(sub, b);
        };
        while (List.size(sub) < 32) {
            List.add<Nat8>(sub, 0);
        };

        Blob.fromArray(List.toArray(sub));
    };

    public let cycles_transfer_fee = 100_000_000;

    public let icp_transfer_fee = 10_000;

    public let minimalFunding = 13_000_000_000_000;

    // Wallet default settings
    // These should match the values used in src/wallet_frontend/src/Settings.tsx
    public let default_amount_add_checkbox = 10.0;
    public let default_amount_add_input = 30.0;
}