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
import Sha256 "mo:sha2/Sha256";
import Itertools "mo:itertools/Iter";

module {
    public func IntHash(value: Int): Hash.Hash { // TODO: letter casing
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
        shortDescription: Text;
        longDescription: Text;
    };

    // Probably, not very efficient.
    public func amendedGUID(guid: Blob, name: PackageName): Blob {
        let b = Buffer.Buffer<Nat8>(guid.size() + name.size());
        b.append(Buffer.fromArray(Blob.toArray(guid)));
        b.append(Buffer.fromArray(Blob.toArray(Text.encodeUtf8(name))));
        let h256 = Sha256.fromArray(#sha256, Buffer.toArray(b));
        Blob.fromArray(Array.subArray(Blob.toArray(h256), 0, 16)); // 128-bit hash
    };

    public type Location = (canister: Principal, id: Nat);

    public type ModuleEvent = {
        #CodeInstalledForAllCanisters;
        #CodeUpgradedForAllCanisters;
    };

    private func moduleEventHash(e: ModuleEvent): Hash.Hash =
        switch (e) {
            case (#CodeInstalledForAllCanisters) 0;
            case (#CodeUpgradedForAllCanisters) 1;
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
        callbacks: [(ModuleEvent, MethodName)];
    };

    public type Module = {
        code: ModuleCode;
        installByDefault: Bool;
        forceReinstall: Bool; // used with such canisters as `MainIndirect`.
        callbacks: HashMap.HashMap<ModuleEvent, MethodName>;
    };

    public func shareModule(m: Module): SharedModule =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
            callbacks = Iter.toArray(m.callbacks.entries());
        };

    public func unshareModule(m: SharedModule): Module =
        {
            code = m.code;
            installByDefault = m.installByDefault;
            forceReinstall = m.forceReinstall;
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
        callbacks: [(ModuleEvent, MethodName)];
    };

    public type CheckInitializedCallback = {
        moduleName: Text;
        how: {
            /// Considered initialized, when doesn't throw.
            #methodName : Text;
            /// Considered initialized, when the URL path (starting with /) exists.
            #urlPath : Text;
        };
    };

    public type SharedRealPackageInfo = {
        /// it's an array, because may contain several canisters.
        modules: [(Text, SharedModule)]; // Modules are named for correct upgrades.
        /// Empty versions list means any version.
        /// Akin Debian:
        dependencies: [(PackageName, [VersionRange])];
        suggests: [(PackageName, [VersionRange])];
        recommends: [(PackageName, [VersionRange])];
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    public type RealPackageInfo = {
        /// it's an array, because may contain several canisters.
        modules: HashMap.HashMap<Text, Module>; // Modules are named for correct upgrades. `Bool` means "install by default".
        /// Empty versions list means any version.
        /// Akin Debian:
        dependencies: [(PackageName, [VersionRange])];
        suggests: [(PackageName, [VersionRange])];
        recommends: [(PackageName, [VersionRange])];
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
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

    public type RealPackageInfoUpload = {
        /// it's an array, because may contain several canisters.
        modules: [(Text, ModuleUpload)]; // Modules are named for correct upgrades.
        /// Empty versions list means any version.
        /// Akin Debian:
        dependencies: [(PackageName, [VersionRange])];
        suggests: [(PackageName, [VersionRange])];
        recommends: [(PackageName, [VersionRange])];
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [MethodName])];
        checkInitializedCallback: ?CheckInitializedCallback;
        frontendModule: ?Text;
    };

    public type VirtualPackageInfo = {
        /// Empty versions list means any version.
        choice: [(PackageName, [VersionRange])];
        /// TODO: Shall we replace it by Suggests/recommends?
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
        // TODO: Uncomment below.
        /// Returns versions with optional other version name
        /// (like `("stable", ?"2.0.4")`).
        ///
        /// TODO: Should it contain aliases from `RepositoryRO.getReleases`? Maybe, not.
        // getPackageVersions: query (name: Text) -> async [(Version, ?Version)];
        getPackage: query (name: PackageName, version: Version) -> async SharedPackageInfo;
        getWasmModule: query (sk: Nat) -> async Blob;
        // packagesByFunction: query (function: Text) -> async [(PackageName, Version)];
    };

    public type InstalledPackageInfo = {
        id: InstallationId;
        package: PackageInfo;
        packageRepoCanister: Principal;
        defaultInstalledModules: HashMap.HashMap<Text, Principal>;
        additionalModules: HashMap.HashMap<Text, Buffer.Buffer<Principal>>;
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
        Iter.concat(pkg.defaultInstalledModules.entries(), additionalModulesIter(pkg.additionalModules));
    };

    public func numberOfModules(pkg: InstalledPackageInfo): Nat {
        pkg.defaultInstalledModules.size() + Iter.size(additionalModulesIter(pkg.additionalModules));
    };

    public type SharedInstalledPackageInfo = {
        id: InstallationId;
        package: SharedPackageInfo;
        packageRepoCanister: Principal;
        defaultInstalledModules: [(Text, Principal)];
        additionalModules: [(Text, [Principal])];
        pinned: Bool;
    };

    public func installedPackageInfoShare(info: InstalledPackageInfo): SharedInstalledPackageInfo = {
        id = info.id;
        package = sharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        defaultInstalledModules = Iter.toArray(info.defaultInstalledModules.entries());
        additionalModules = Iter.toArray(
            Iter.map<(Text, Buffer.Buffer<Principal>), (Text, [Principal])>(
                info.additionalModules.entries(),
                func ((k, v): (Text, Buffer.Buffer<Principal>)): (Text, [Principal]) = (k, Buffer.toArray(v))
            )
        );
        pinned = info.pinned;
    };

    public func installedPackageInfoUnshare(info: SharedInstalledPackageInfo): InstalledPackageInfo = {
        id = info.id;
        package = unsharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        defaultInstalledModules = HashMap.fromIter(
            info.defaultInstalledModules.vals(),
            info.defaultInstalledModules.size(),
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

    public type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    public type canister_id = Principal;
    public type wasm_module = Blob;

    // TODO: Remove.
    public type CanisterCreator = actor {
        // create_canister : shared { settings : ?canister_settings } -> async {
        //     canister_id : canister_id;
        // };
        install_code : shared {
            arg : [Nat8];
            wasm_module : wasm_module;
            mode : { #reinstall; #upgrade; #install };
            canister_id : canister_id;
        } -> async ();
    };

    public func extractModuleLocation(code: ModuleCode): (Principal, Nat) =
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
}