import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Text "mo:base/Text";
import OrderedHashMap "mo:ordered-map";

module {
    public let NamespacePrefix = "b44c4a9beec74e1c8a7acbe46256f92f_";

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

    public type Module = {
        #Wasm : Location;
        #Assets : {
            wasm: Location;
            assets: Principal;
        }
    };

    /// Shared/query method name.
    public type MethodName = Text;

    public type RealPackageInfo = {
        /// it's an array, because may contain several canisters.
        modules: [(Text, Module)]; // Modules are named for correct upgrades.
        extraModules: [(Text, Module)]; // to be installed on-demand
        /// Empty versions list means any version.
        ///
        /// TODO: Suggests/recommends akin Debian.
        dependencies: [(PackageName, [VersionRange])];
        // TODO: Introduce dependencies between modules.
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: [(Text, [(Principal, MethodName)])];
    };

    public type VirtualPackageInfo = {
        /// Empty versions list means any version.
        choice: [(PackageName, [VersionRange])];
        /// TODO: Shall we replace it by Suggests/recommends?
        default: PackageName;
    };

    public type PackageInfo = {
        base: CommonPackageInfo;
        specific: {
            #real : RealPackageInfo;
            #virtual : VirtualPackageInfo;
        };
    };

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
        getPackage: query (name: Text, version: Version) -> async PackageInfo;
        // packagesByFunction: query (function: Text) -> async [(PackageName, Version)];
    };

    public type InstalledPackageInfo = {
        id: InstallationId;
        name: PackageName;
        package: PackageInfo;
        packageCanister: Principal;
        version: Version; // TODO: Remove it everywhere. because it's in PackageInfo?
        modules: OrderedHashMap.OrderedHashMap<Text, Principal>; // TODO: why ordered?
        var extraModules: [(Text, Principal)]; // TODO: `HashMap`?
    };

    public type SharedInstalledPackageInfo = {
        id: InstallationId;
        name: PackageName;
        package: PackageInfo;
        packageCanister: Principal;
        version: Version;
        modules: [(Text, Principal)];
        extraModules: [(Text, Principal)];
    };

    public func installedPackageInfoShare(info: InstalledPackageInfo): SharedInstalledPackageInfo = {
        id = info.id;
        name = info.name;
        package = info.package;
        packageCanister = info.packageCanister;
        version = info.version;
        modules = Iter.toArray(info.modules.entries());
        extraModules = info.extraModules;
    };

    public func installedPackageInfoUnshare(info: SharedInstalledPackageInfo): InstalledPackageInfo = {
        id = info.id;
        name = info.name;
        package = info.package;
        packageCanister = info.packageCanister;
        version = info.version;
        modules = OrderedHashMap.fromIter(info.modules.vals(), Array.size(info.modules), Text.equal, Text.hash);
        var extraModules = info.extraModules;
    };

    // Remark: There can be same named real package and a virtual package (of different versions).
    public type FullPackageInfo = {
        packages: [(Version, PackageInfo)];
        versionsMap: [(Version, Version)];
    };

    public type HalfInstalledPackageInfo = {
        shouldHaveModules: Nat;
        packageCanister: Principal;
        name: PackageName;
        version: Version;
        modules: OrderedHashMap.OrderedHashMap<Text, (Principal, {#empty; #installed})>; // TODO: need ordered?
        package: PackageInfo;
        preinstalledModules: ?[(Text, Principal)];
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
        create_canister : shared { settings : ?canister_settings } -> async {
            canister_id : canister_id;
        };
        install_code : shared {
            arg : [Nat8];
            wasm_module : wasm_module;
            mode : { #reinstall; #upgrade; #install };
            canister_id : canister_id;
        } -> async ();
    };
}