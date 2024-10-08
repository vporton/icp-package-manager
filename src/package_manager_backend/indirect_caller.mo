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
        label cycle for (method in methods.vals()) {
            try {
                ignore await IC.call(method.canister, method.name, method.data); 
            }
            catch (e) {
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
                break cycle;
            };
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
                let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
                Debug.print(msg);
                Debug.trap(msg);
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
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared({caller}) func call(method: {canister: Principal; name: Text; data: Blob}): async Blob {
        onlyOwner(caller);

        try {
            return await IC.call(method.canister, method.name, method.data);
        }
        catch (e) {
            let msg = "Indirect caller (" # method.name # "): " # Error.message(e);
            Debug.print(msg);
            Debug.trap(msg);
        };
    };

    public shared({caller}) func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async () {
        onlyOwner(caller);

        try {
            return await* CopyAssets.copyAll({from; to});
        }
        catch (e) {
            Debug.print("Indirect caller copyAll: " # Error.message(e));
            Debug.trap("Indirect caller copyAll: " # Error.message(e));
        };
    };

    public shared({caller}) func installPackageWrapper({
        repo: Common.RepositoryPartitionRO; // TODO: Rename.
        pmPrincipal: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        installationId: Common.InstallationId;
        preinstalledModules: ?[(Text, Principal)];
        data: Blob;
        callback: ?(shared ({
            installationId: Common.InstallationId;
            data: Blob;
        }) -> async ());
    }) {
        onlyOwner(caller);

        try {
            let package = await repo.getPackage(packageName, version); // unsafe operation, run in indirect_caller

            let pm = actor (Principal.toText(pmPrincipal)) : actor {
                // getHalfInstalledPackageById: query (installationId: Common.InstallationId) -> async {
                //     packageName: Text;
                //     version: Common.Version;
                //     package: Common.PackageInfo;
                // };
                installPackageCallback: ({
                    packageName: Common.PackageName;
                    version: Common.Version;
                    package: Common.PackageInfo;
                    installationId: Common.InstallationId;
                    repo: Common.RepositoryPartitionRO; // TODO: needed?
                    preinstalledModules: ?[(Text, Principal)];
                }) -> async ();
            };
            // let info = await pm.getHalfInstalledPackageById(installationId);

            Debug.print("Call installPackageCallback");
            await pm.installPackageCallback({
                installationId;
                packageName;
                version;
                package;
                repo;
                preinstalledModules;
            });
            switch (callback) {
                case (?callback) {
                    await callback({installationId; can = pmPrincipal; caller; package; data});
                };
                case null {};
            };
        }
        catch (e) {
            Debug.print("installPackageWrapper: " # Error.message(e));
        };
    };
}