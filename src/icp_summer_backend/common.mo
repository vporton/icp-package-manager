import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import PackageManager "package_manager";

module {
    // TODO: updating the packages.

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
        dependencies: [(PackageName, [VersionRange])];
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: HashMap.HashMap<Text, [(Principal, MethodName)]>;
    };

    public type VirtualPackageInfo = {
        /// Empty versions list means any version.
        choice: [(PackageName, [VersionRange])];
    };

    public type PackageInfo = {
        base: CommonPackageInfo;
        specific: {
            #real : RealPackageInfo;
            #virtual : VirtualPackageInfo;
        };
    };

    type InstallationId = Nat;

    type RepositoryIndexRO = actor {
        getPartitions: query () -> async [RepositoryPartitionRO];
        getRepositoryName: query () -> async Text;
        getRepositoryInfoURL: query () -> async Text;
        /// Returns releases with optional other release name
        /// (like `("stable", ?"morpheus")`).
        getReleases: query () -> async [(Text, ?Text)];
    };

    type RepositoryPartitionRO = actor {
        /// Returns versions with optional other version name
        /// (like `("stable", ?"2.0.4")`).
        ///
        /// TODO: Should it contain aliases from `RepositoryIndexRO.getReleases`? Maybe, not.
        getPackageVersions: query (name: Text) -> async [(Version, ?Version)];
        getPackage: query (name: Text, version: Version) -> async Common.PackageInfo;
        packagesByFunction: query (function: Text) -> [(Common.PackageName, Common.Version)];
    };
}