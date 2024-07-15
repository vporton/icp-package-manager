import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";

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

    /// Shared/query method name.
    public type MethodName = Text;

    public type RealPackageInfo = {
        /// it's an array, because may contain several canisters.
        wasms: [Location];
        /// Empty versions list means any version.
        ///
        /// TODO: Suggests/recommends akin Debian.
        dependencies: [(PackageName, [VersionRange])];
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
        packageCanister: Principal;
        version: Version;
        modules: [Principal];
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
        modules: Buffer.Buffer<Principal>;
        package: PackageInfo;
    };
}