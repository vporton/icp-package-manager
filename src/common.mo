import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Sha256 "mo:sha2/Sha256";
import Itertools "mo:itertools/Iter";
import Account "lib/Account";

module {
    public func intHash(value: Int): Hash.Hash {
        var v2 = Int.abs(value);
        var hash: Nat32 = 0;
        while (v2 != 0) {
            let rem = v2 % (2**32);
            v2 /= 2**32;
            hash ^= Nat32.fromNat(rem);
        };
        if (value < 0) {
            hash ^= Nat32.fromNat(2**32 - 1); // invert every bit
        };
        hash;
    };

    public type PackageName = Text;

    // Can be like `6.8.4` or like `stable`, `unstable`, `prerelease`.
    public type Version = Text;

    public type VersionRange = (Version, Version);

    /// Common properties of package and virtual package.
    public type CommonPackageInfo = {
        guid: Blob;
        name: PackageName;
        version: Version;
        price: Nat;
        shortDescription: Text;
        longDescription: Text;
        developer: ?Account.Account;
    };

    // Probably, not very efficient.
    public func amendedGUID(guid: Blob, name: PackageName): Blob {
        let b = Buffer.Buffer<Nat8>(guid.size() + name.size());
        b.append(Buffer.fromArray(Blob.toArray(guid)));
        b.append(Buffer.fromArray(Blob.toArray(Text.encodeUtf8(name))));
        let h256 = Sha256.fromArray(#sha256, Buffer.toArray(b));
        Blob.fromArray(Array.subArray(Blob.toArray(h256), 0, 16)); // 128-bit hash
    };

    public type Location = (canister: Principal, id: Blob); // `id` is a 128-bit hash of the module code.

    public type ModuleEvent = {
        #CodeInstalledForAllCanisters;
        #CodeUpgradedForAllCanisters;
        #WithdrawCycles;
    };

    private func moduleEventHash(e: ModuleEvent): Hash.Hash =
        switch (e) {
            case (#CodeInstalledForAllCanisters) 0;
            case (#CodeUpgradedForAllCanisters) 1;
            case (#WithdrawCycles) 2;
        };

    /// Shared/query method name.
    public type MethodName = {method: Text};

    public type ModuleCode = {
        #Wasm : Location;
        #Assets : {
            wasm: Location;
            assets: Principal;
        };
    };

    public type SharedModule = {
        code: ModuleCode;
        installByDefault: Bool;
        forceReinstall: Bool;
        canisterVersion: ?Nat64; // sender_canister_version
        callbacks: [(ModuleEvent, MethodName)];
    };

    public type Module = {
        code: ModuleCode;
        installByDefault: Bool;
        forceReinstall: Bool; // used with such canisters as `MainIndirect`.
        canisterVersion: ?Nat64; // sender_canister_version
        callbacks: HashMap.HashMap<ModuleEvent, MethodName>;
    };

    public func shareModule(m: Module): SharedModule =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
            canisterVersion = m.canisterVersion;
            callbacks = Iter.toArray(m.callbacks.entries());
        };

    public func unshareModule(m: SharedModule): Module =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
            canisterVersion = m.canisterVersion;
            callbacks = HashMap.fromIter(
                m.callbacks.vals(),
                m.callbacks.size(),
                func (a: ModuleEvent, b: ModuleEvent): Bool = a == b,
                moduleEventHash,
            );
        };

    public type ModuleUploadCode = {
        #Wasm : Blob;
        #Assets : {
            wasm: Blob;
            assets: Principal;
        };
    };

    public type ModuleUpload = {
        code: ModuleUploadCode;
        installByDefault: Bool;
        forceReinstall: Bool;
        canisterVersion: ?Nat64; // sender_canister_version
        callbacks: [(ModuleEvent, MethodName)];
    };

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

    /// See `RealPackageInfo`.
    public type SharedRealPackageInfo = {
        modules: [(Text, SharedModule)]; // Modules are named for correct upgrades.
        dependencies: [(PackageName, ?[VersionRange])];
        suggests: [(PackageName, ?[VersionRange])];
        recommends: [(PackageName, ?[VersionRange])];
        functions: [(PackageName, ?[VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    /// `dependencies`, `suggests`, `recommends` (akin Debian) are currently not supported.
    /// Package's `functions` (currently not supported) are unrelated to Motoko functions.
    /// `modules` are named canisters. (Names are needed for example to know which module should be
    /// replaced by which during an upgrade.)
    public type RealPackageInfo = {
        modules: HashMap.HashMap<Text, Module>; // Modules are named for correct upgrades. `Bool` means "install by default".
        dependencies: [(PackageName, ?[VersionRange])];
        suggests: [(PackageName, ?[VersionRange])];
        recommends: [(PackageName, ?[VersionRange])];
        functions: [(PackageName, ?[VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    public func shareRealPackageInfo(package: RealPackageInfo): SharedRealPackageInfo =
        {
            modules = Iter.toArray(
                Iter.map<(Text, Module), (Text, SharedModule)>(
                    package.modules.entries(),
                    func ((k, m): (Text, Module)): (Text, SharedModule) = (k, shareModule(m)),
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

    public func unshareRealPackageInfo(package: SharedRealPackageInfo): RealPackageInfo =
        {
            modules = HashMap.fromIter(
                Iter.map<(Text, SharedModule), (Text, Module)>(
                    package.modules.vals(),
                    func ((k, m): (Text, SharedModule)): (Text, Module) = (k, unshareModule(m)),
                ),
                package.modules.size(),
                Text.equal,
                Text.hash,
            );
            dependencies = package.dependencies;
            suggests = package.suggests;
            recommends = package.recommends;
            functions = package.functions;
            permissions = package.permissions;
            checkInitializedCallback = package.checkInitializedCallback;
            frontendModule = package.frontendModule;
        };

    /// See `RealPackageInfo`.
    public type RealPackageInfoUpload = {
        modules: [(Text, ModuleUpload)]; // Modules are named for correct upgrades.
        dependencies: [(PackageName, ?[VersionRange])];
        suggests: [(PackageName, ?[VersionRange])];
        recommends: [(PackageName, ?[VersionRange])];
        functions: [(PackageName, ?[VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    /// Yet unsupported.
    public type VirtualPackageInfo = {
        choice: [(PackageName, ?[VersionRange])];
        default: PackageName;
    };

    public type SharedPackageInfo = {
        base: CommonPackageInfo;
        specific: {
            #real : SharedRealPackageInfo;
            #virtual : VirtualPackageInfo;
        };
    };

    public type PackageInfo = {
        base: CommonPackageInfo;
        specific: {
            #real : RealPackageInfo;
            #virtual : VirtualPackageInfo;
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
        var modulesInstalledByDefault: HashMap.HashMap<Text, Principal>;
        additionalModules: HashMap.HashMap<Text, Buffer.Buffer<Principal>>;
        /// Public key used to verify configuration requests for this installation.
        var pubKey: ?Blob;
        var pinned: Bool;
    };

    private func additionalModulesIter(additionalModules: HashMap.HashMap<Text, Buffer.Buffer<Principal>>)
        : Iter.Iter<(Text, Principal)>
    {
        Itertools.flatten(
            Iter.map<(Text, Buffer.Buffer<Principal>), Iter.Iter<(Text, Principal)>>(
                additionalModules.entries(),
                func ((name, buf): (Text, Buffer.Buffer<Principal>)) = Itertools.zip(Iter.make(name), buf.vals()),
            ),
        );
    };

    // Tested in `modulesIter.test.mo`.
    /// Iterate over all modules in `pkg.namedModules`.
    public func modulesIterator(pkg: InstalledPackageInfo): Iter.Iter<(Text, Principal)> {
        Iter.concat(pkg.modulesInstalledByDefault.entries(), additionalModulesIter(pkg.additionalModules));
    };

    public func numberOfModules(pkg: InstalledPackageInfo): Nat {
        pkg.modulesInstalledByDefault.size() + Iter.size(additionalModulesIter(pkg.additionalModules));
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

    public func installedPackageInfoShare(info: InstalledPackageInfo): SharedInstalledPackageInfo = {
        id = info.id;
        package = sharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        modulesInstalledByDefault = Iter.toArray(info.modulesInstalledByDefault.entries());
        additionalModules = Iter.toArray(
            Iter.map<(Text, Buffer.Buffer<Principal>), (Text, [Principal])>(
                info.additionalModules.entries(),
                func ((k, v): (Text, Buffer.Buffer<Principal>)): (Text, [Principal]) = (k, Buffer.toArray(v))
            )
        );
        pubKey = info.pubKey;
        pinned = info.pinned;
    };

    public func installedPackageInfoUnshare(info: SharedInstalledPackageInfo): InstalledPackageInfo = {
        id = info.id;
        var package = unsharePackageInfo(info.package);
        var packageRepoCanister = info.packageRepoCanister;
        var modulesInstalledByDefault = HashMap.fromIter(
            info.modulesInstalledByDefault.vals(),
            info.modulesInstalledByDefault.size(),
            Text.equal,
            Text.hash,
        );
        additionalModules = HashMap.fromIter(
            Iter.map<(Text, [Principal]), (Text, Buffer.Buffer<Principal>)>(
                info.additionalModules.vals(),
                func ((k, v): (Text, [Principal])): (Text, Buffer.Buffer<Principal>) = (k, Buffer.fromArray(v))
            ),
            info.additionalModules.size(),
            Text.equal,
            Text.hash,
        );
        var pubKey = info.pubKey;
        var pinned = info.pinned;
    };

    // Remark: There can be same named real package and a virtual package (of different versions).
    public type SharedFullPackageInfo = {
        packages: [(Version, SharedPackageInfo)];
        versionsMap: [(Version, Version)];
    };

    // Remark: There can be same named real package and a virtual package (of different versions).
    public type FullPackageInfo = {
        packages: HashMap.HashMap<Version, PackageInfo>;
        versionsMap: HashMap.HashMap<Version, Version>;
    };

    public func shareFullPackageInfo(info: FullPackageInfo): SharedFullPackageInfo =
        {
            packages = Iter.toArray(
                Iter.map<(Version, PackageInfo), (Version, SharedPackageInfo)>(
                    info.packages.entries(),
                    func ((v, i): (Version, PackageInfo)): (Version, SharedPackageInfo) = (v, sharePackageInfo(i)),
                ),
            );
            versionsMap = Iter.toArray(info.versionsMap.entries());
        };

    public func unshareFullPackageInfo(info: SharedFullPackageInfo): FullPackageInfo =
        {
            packages = HashMap.fromIter(
                Iter.map<(Version, SharedPackageInfo), (Version, PackageInfo)>(
                    info.packages.vals(),
                    func ((v, i): (Version, SharedPackageInfo)): (Version, PackageInfo) = (v, unsharePackageInfo(i)),
                ),
                info.packages.size(),
                Text.equal,
                Text.hash,
            );
            versionsMap = HashMap.fromIter(
                info.versionsMap.vals(),
                info.versionsMap.size(),
                Text.equal,
                Text.hash,
            );
        };

    public func extractModuleLocation(code: ModuleCode): (Principal, Blob) =
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
        var sub = Buffer.Buffer<Nat8>(32);
        let subaccount_blob = Principal.toBlob(principal);

        sub.add(Nat8.fromNat(subaccount_blob.size()));
        sub.append(Buffer.fromArray<Nat8>(Blob.toArray(subaccount_blob)));
        while (sub.size() < 32) {
            sub.add(0);
        };

        Blob.fromArray(Buffer.toArray(sub));
    };

    public let cycles_transfer_fee = 100_000_000;

    public let icp_transfer_fee = 10_000;

    public let minimalFunding = 13_000_000_000_000;
}