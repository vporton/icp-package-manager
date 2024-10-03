/// Canister that takes on itself potentially non-returning calls.
import IC "mo:base/ExperimentalInternetComputer";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Asset "mo:assets-api";
import Common "../common";
import CopyAssets "../copy_assets";

shared({caller = initialOwner}) actor class IndirectCaller() = this {
    stable var owner = initialOwner;

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal) {
        if (caller != owner and caller != Principal.fromActor(this)) { // TODO: Comparison with this is necessary for call of `copyAssets` from `callAllOneWay`.
            Debug.print("only owner");
            Debug.trap("only owner");
        };
    };

    public shared({caller}) func setOwner(newOwner: Principal): async () {
        onlyOwner(caller);

        owner := newOwner;
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, stop.
    private func callAllOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        try {
            for (method in methods.vals()) {
                ignore await IC.call(method.canister, method.name, method.data); 
            };
        }
        catch (e) {
            Debug.print("Indirect caller: " # Error.message(e));
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    /// Call methods in the given order and don't return.
    ///
    /// If a method is missing, keep calling other methods.
    private func callIgnoringMissingOneWayImpl(caller: Principal, methods: [{canister: Principal; name: Text; data: Blob}]): async* () {
        for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data);
            }
            catch (e) {
                Debug.print("Indirect caller: " # Error.message(e));
                Debug.trap("Indirect caller: " # Error.message(e));
                if (Error.code(e) != #call_error {err_code = 302}) { // CanisterMethodNotFound
                    throw e; // Other error cause interruption.
                }
            };
        };
    };

    public shared({caller}) func callIgnoringMissingOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        await* callIgnoringMissingOneWayImpl(caller, methods)
    };

    public shared({caller}) func callAllOneWay(methods: [{canister: Principal; name: Text; data: Blob}]): () {
        onlyOwner(caller);

        await* callAllOneWayImpl(caller, methods);
    };

    public shared({caller}) func callIgnoringMissing(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        try {
            return await IC.call(method.canister, method.name, method.data); 
        }
        catch (e) {
            Debug.print("Indirect caller: " # Error.message(e));
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    public shared({caller}) func call(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        try {
            return await IC.call(method.canister, method.name, method.data);
        }
        catch (e) {
            Debug.print("Indirect caller: " # Error.message(e));
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    public shared({caller}) func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async () {
        onlyOwner(caller);

        try {
            return await* CopyAssets.copyAll({from; to});
        }
        catch (e) {
            Debug.print("Indirect caller: " # Error.message(e));
            Debug.trap("Indirect caller: " # Error.message(e));
        };
    };

    public shared({caller}) func installPackageWrapper({
        installationId: Common.InstallationId;
        pmPrincipal: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
    }) {
        onlyOwner(caller);

        try {
            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                getHalfInstalledPackageById: query (installationId: Common.InstallationId) -> async {
                    packageName: Text;
                    version: Common.Version;
                    package: Common.PackageInfo;
                };
                installPackageCallback: ({
                    installationId: Common.InstallationId;
                    packageName: Common.PackageName;
                    version: Common.Version;
                    package: Common.PackageInfo;
                }) -> async ();
            };
            // TODO: Is the below over-engineering?
            let info = await pm.getHalfInstalledPackageById(installationId);

            type o = actor {
                // TODO: Check it carefully.
                installPackageCallback: ({
                    installationId: Common.InstallationId;
                    packageName: Common.PackageName;
                    version: Common.Version;
                    package: Common.PackageInfo;
                }) -> async ();
            };
            Debug.print("Call installPackageCallback");
            await pm.installPackageCallback({
                installationId;
                packageName;
                version;
                package = /*Common.installedPackageInfoUnshare(*/info.package/*)*/;
            });
        }
        catch (e) {
            Debug.print("installPackageWrapper: " # Error.message(e));
        };
    };
}