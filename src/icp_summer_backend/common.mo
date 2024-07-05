import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";

module {
    // TODO: updating the packages.

    public type PackageName = Text;

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
        base: CommonPackageInfo;
        /// it's an array, because may contain several canisters.
        wasms: [Location];
        /// Empty versions list means any version.
        dependencies: [(PackageName, [VersionRange])];
        /// Package functions are unrelated to Motoko functions. Empty versions list means any version.
        functions: [(PackageName, [VersionRange])];
        permissions: HashMap.HashMap<Text, [(Principal, MethodName)]>;
    };

    public type VirtualPackageInfo = {
        base: CommonPackageInfo;
        /// Empty versions list means any version.
        choice: [(PackageName, [VersionRange])];
    };
}