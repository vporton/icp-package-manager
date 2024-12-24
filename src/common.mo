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
import Entity "mo:candb/Entity";

module {
    public func IntHash(value: Int): Hash.Hash {
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
        name: PackageName;
        version: Version;
        shortDescription: Text;
        longDescription: Text;
    };

    public type Location = (canister: Principal, id: Text);

    public type ModuleEvent = {
        // TODO: The following events could be delivered to a not yet installed or uploaded canister, KISS.
        // TODO: Add thefollowing events by first creating all the canisters and THEN installing code.
        // #CanisterCreated;
        // #CodeInstalled;
        // #AllCanistersCreated;
        #CodeInstalledForAllCanisters;
        // TODO: Event like `#CodeInstalled` for a particular module, but fired only after all canisters are created.
    };

    private func moduleEventHash(e: ModuleEvent): Hash.Hash =
        switch (e) {
            // case (#CanisterCreated) 0;
            // case (#CodeInstalled) 1;
            // case (#AllCanistersCreated) 2;
            case (#CodeInstalledForAllCanisters) 3; // TODO: value
        };

    /// Shared/query method name.
    public type MethodName = {method: Text}; // TODO: simplify?

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
        forceReinstall: Bool; // used with such canisters as `IndirectCaller`.
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

    public type SharedRealPackageInfo = {
        /// it's an array, because may contain several canisters.
        modules: [(Text, SharedModule)]; // Modules are named for correct upgrades. `Bool` means "install by default".
        /// Empty versions list means any version.
        ///
        /// TODO: Suggests/recommends akin Debian.
        dependencies: [(PackageName, [VersionRange])];
        // TODO: Introduce dependencies between modules.
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [MethodName])];
    };

    public type RealPackageInfo = {
        /// it's an array, because may contain several canisters.
        modules: HashMap.HashMap<Text, Module>; // Modules are named for correct upgrades. `Bool` means "install by default".
        /// Empty versions list means any version.
        ///
        /// TODO: Suggests/recommends akin Debian.
        dependencies: [(PackageName, [VersionRange])];
        // TODO: Introduce dependencies between modules.
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [MethodName])];
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
            functions = package.functions;
            permissions = package.permissions;
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
            functions = package.functions;
            permissions = package.permissions;
        };

    public type RealPackageInfoUpload = {
        /// it's an array, because may contain several canisters.
        modules: [(Text, ModuleUpload)]; // Modules are named for correct upgrades.
        /// Empty versions list means any version.
        ///
        /// TODO: Suggests/recommends akin Debian.
        dependencies: [(PackageName, [VersionRange])];
        // TODO: Introduce dependencies between modules.
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [MethodName])];
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

    public type RepositoryIndexRO = actor {
        getRepositoryPartitions: query () -> async [RepositoryPartitionRO];
        getRepositoryName: query () -> async Text;
        getRepositoryInfoURL: query () -> async Text;
        /// Returns releases with optional other release name
        /// (like `("stable", ?"morpheus")`).
        getReleases: query () -> async [(Text, ?Text)];
    };

    public type RepositoryPartitionRO = actor {
        // TODO: Uncomment below.
        /// Returns versions with optional other version name
        /// (like `("stable", ?"2.0.4")`).
        ///
        /// TODO: Should it contain aliases from `RepositoryIndexRO.getReleases`? Maybe, not.
        // getPackageVersions: query (name: Text) -> async [(Version, ?Version)];
        getPackage: query (name: PackageName, version: Version) -> async SharedPackageInfo;
        // packagesByFunction: query (function: Text) -> async [(PackageName, Version)];
        getAttribute: query (sk: Text, subkey: Text) -> async ?Entity.AttributeValue; // TODO: Probably shouldn't be here.
    };

    public type InstalledPackageInfo = {
        id: InstallationId;
        name: PackageName;
        package: PackageInfo;
        packageRepoCanister: Principal;
        version: Version; // TODO: Remove it everywhere. because it's in PackageInfo?
        modules: HashMap.HashMap<Text, Principal>; // TODO: Rename to `namedModules`.
        allModules: Buffer.Buffer<Principal>; // for uninstallation and cycles managment
    };

    public type SharedInstalledPackageInfo = {
        id: InstallationId;
        name: PackageName;
        package: SharedPackageInfo;
        packageRepoCanister: Principal;
        version: Version;
        modules: [(Text, Principal)];
        allModules: [Principal];
    };

    public func installedPackageInfoShare(info: InstalledPackageInfo): SharedInstalledPackageInfo = {
        id = info.id;
        name = info.name;
        package = sharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        version = info.version;
        modules = Iter.toArray(info.modules.entries());
        allModules = Buffer.toArray(info.allModules);
    };

    public func installedPackageInfoUnshare(info: SharedInstalledPackageInfo): InstalledPackageInfo = {
        id = info.id;
        name = info.name;
        package = unsharePackageInfo(info.package);
        packageRepoCanister = info.packageRepoCanister;
        version = info.version;
        modules = HashMap.fromIter(info.modules.vals(), Array.size(info.modules), Text.equal, Text.hash);
        allModules = Buffer.fromArray(info.allModules);
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

    /// TODO: Rename.
    public type HalfInstalledPackageInfo = {
        numberOfModulesToInstall: Nat; // TODO: Remove in regard of `modulesToInstall`.
        modulesToInstall: HashMap.HashMap<Text, Module>;
        packageRepoCanister: Principal; // TODO: needed? move to `#package`?
        packageName: PackageName;
        whatToInstall: {
            #package;
            #simplyModules : [(Text, SharedModule)];
        };
        modulesWithoutCode: Buffer.Buffer<?(?Text, Principal)>;
        installedModules: Buffer.Buffer<?(?Text, Principal)>;
        package: PackageInfo;
        preinstalledModules: HashMap.HashMap<Text, Principal>;
        var alreadyCalledAllCanistersCreated: Bool;
    };

    public type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    public type canister_id = Principal;
    public type wasm_module = Blob;

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

    public func extractModuleLocation(code: ModuleCode): (Principal, Text) =
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