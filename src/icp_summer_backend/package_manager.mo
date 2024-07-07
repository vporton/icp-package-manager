import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Common "common";
import indirect_caller "canister:indirect_caller";

shared({caller}) actor class PackageManager() = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(caller, ())].vals(), 1, Principal.equal, Principal.hash);

    stable var nextInstallationId: Nat = 0;

    /// TODO: Move to `common.mo`.
    type InstalledPackageInfo = {
        id: Common.InstallationId;
        name: Common.PackageName;
        version: Common.Version;
        modules: [Principal];
    };

    stable var _installedPackagesSave: [(Common.InstallationId, [InstalledPackageInfo])] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Buffer.Buffer<InstalledPackageInfo>> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Int.hash);

    stable var _installedPackagesByNameSave: [(Common.PackageName, [Common.InstallationId])] = [];
    var installedPackagesByName: HashMap.HashMap<Common.PackageName, [Common.InstallationId]> =
        HashMap.fromIter([].vals(), 0, Text.equal, Text.hash);

    /// TODO: Move to `common.mo`.
    type HalfInstalledPackageInfo = {
        shouldHaveModules: Nat;
        name: Common.PackageName;
        version: Common.Version;
        modules: Buffer.Buffer<Principal>;
    };

    stable var _halfInstalledPackagesSave: [{
        shouldHaveModules: Nat;
        name: Common.PackageName;
        version: Common.Version;
        modules: [Principal];
    }] = [];
    var halfInstalledPackages: Buffer.Buffer<HalfInstalledPackageInfo> = Buffer.Buffer(1);

    func onlyOwner(caller: Principal) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner");
        }
    };

    type canister_settings = {
        freezing_threshold : ?Nat;
        controllers : ?[Principal];
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };

    type canister_id = Principal;
    type wasm_module = Blob;

    type CanisterCreator = actor {
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

    /// We don't install dependencies here (see `specs.odt`).
    public shared({caller}) func installPackage({
        part: Common.RepositoryPartitionRO;
        packageName: Common.PackageName;
        version: Common.Version;
    })
        : async Common.InstallationId
    {
        let package = await part.getPackage(packageName, version);
        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        let numPackages = Array.size(realPackage.wasms);

        let installationId = nextInstallationId;
        nextInstallationId += 1;
        let ourHalfInstalled = {
            shouldHaveModules = numPackages;
            id = installationId;
            name = package.base.name;
            version = package.base.version;
            modules = Buffer.Buffer<Principal>(numPackages);
        };
        halfInstalledPackages.add(ourHalfInstalled);

        let IC: CanisterCreator = actor("aaaaa-aa");

        let canisters = Buffer.Buffer<Principal>(numPackages);
        // TODO: Don't wait for creation of a previous canister to create the next one.
        for (wasmModuleLocation in realPackage.wasms.vals()) {
            // TODO: cycles (and monetization)
            let {canister_id} = await IC.create_canister({
                freezing_threshold = null; // FIXME: 30 days may be not enough, make configurable.
                controllers = null; // We are the controller.
                compute_allocation = null; // TODO
                memory_allocation = null; // TODO (a low priority task)
            });
            let wasmModuleSourcePartition: CanDBPartition = actor(wasmModuleLocation.0);
            let ?(#blob wasm_module) = wasmModuleSourcePartition.get({sk = wasmModuleLocation.1}) else {
                // TODO: Delete installed modules and start anew. (Should we deinit them?)
                // TODO: What to do if deleting fails, too? Should track partly installed and use frontend to delete.
                Debug.trap("package WASM code is not available");
            };
            await IC.install_code({
                arg = to_candid({user = caller; previousCanisters = canisters; packageManager = this});
                wasm_module;
                mode = #install;
                canister_id;
            });
            canisters.add(canister_id);
        };
        indirect_caller.callIgnoringMissing(
            Iter.toArray(Iter.map<Nat, {canister: Principal; name: Text; data: Blob}>(
                Buffer.toArray(canisters).keys(), // TODO: inefficient?
                func (i: Nat) = {
                    canister = canisters.get(i);
                    name = Common.NamespacePrefix # "init";
                    data = to_candid({
                        user = caller;
                        previousCanisters = Array.subArray<Principal>(Buffer.toArray(canisters), 0, i);
                        packageManager = this;
                    });
                },
            )),
        );

        // TODO: Write to the local registry of installed packages.
        installationId;
    };

    system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());

        _installedPackagesSave := Iter.toArray(Iter.map<
            (Common.InstallationId, Buffer.Buffer<InstalledPackageInfo>), (Common.InstallationId, [InstalledPackageInfo])
        >(
            installedPackages.entries(),
            func (p: (Common.InstallationId, Buffer.Buffer<InstalledPackageInfo>))
                : (Common.InstallationId, [InstalledPackageInfo])
                = (p.0, Buffer.toArray(p.1)),
        ));

        _installedPackagesByNameSave := Iter.toArray(installedPackagesByName.entries());

        // TODO:
        // _halfInstalledPackagesSave := Iter.toArray(Iter.map(
        //     halfInstalledPackages,
        //     {
        //         shouldHaveModules: Nat;
        //         name: Common.PackageName;
        //         version: Common.Version;
        //         modules: [Principal];
        //     }
        // ));
    };

    system func postupgrade() {
        owners := HashMap.fromIter(
            _ownersSave.vals(),
            Array.size(_ownersSave),
            Principal.equal,
            Principal.hash,
        );
        _ownersSave := []; // Free memory.

        installedPackages := HashMap.fromIter(Iter.map<
            (Common.InstallationId, [InstalledPackageInfo]), (Common.InstallationId, Buffer.Buffer<InstalledPackageInfo>)
        >(
            _installedPackagesSave.vals(),
            func (p: (Common.InstallationId, [InstalledPackageInfo]))
                : (Common.InstallationId, Buffer.Buffer<InstalledPackageInfo>)
                = (p.0, Buffer.fromArray(p.1))
            ),
            Array.size(_installedPackagesSave),
            Nat.equal,
            Int.hash,
        );
        _installedPackagesSave := []; // Free memory.

        installedPackagesByName := HashMap.fromIter(
            _installedPackagesByNameSave.vals(),
            Array.size(_installedPackagesByNameSave),
            Text.equal,
            Text.hash,
        );
        _installedPackagesByNameSave := []; // Free memory.

        // halfInstalledPackages := TODO;
        _halfInstalledPackagesSave := []; // Free memory.
    };
}