import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import OrderedHashMap "mo:ordered-map";
import Common "../common";
import RepositoryPartition "../repository_backend/RepositoryPartition";
import IndirectCaller "indirect_caller";
import Install "../install";
import cycles_ledger "canister:cycles_ledger";

/// TODO: Methods to query for all installed packages.
shared({caller = initialOwner}) actor class PackageManager() = this {
    stable var _ownersSave: [(Principal, ())] = [];
    var owners: HashMap.HashMap<Principal, ()> =
        HashMap.fromIter([(initialOwner, ())].vals(), 1, Principal.equal, Principal.hash);

    // TODO: more flexible control of owners
    public shared({caller}) func setOwner(newOwner: Principal): async () {
        onlyOwner(caller);

        owners := HashMap.fromIter([(newOwner, ())].vals(), 1, Principal.equal, Principal.hash);
    };

    var initialized: Bool = false; // intentionally non-stable // TODO: separate variable for signaling upgrading?

    // TODO: needed?
    public shared({caller}) func b44c4a9beec74e1c8a7acbe46256f92f_init({
        user: Principal;
        indirect_caller: Principal;
    }) : async () {
        indirect_caller_ := ?actor(Principal.toText(indirect_caller));
        owners := HashMap.fromIter([(user, ())].vals(), 1, Principal.equal, Principal.hash);

        initialized := true; // TODO: Re-enable this assignment.
    };

    // TODO
    public shared func b44c4a9beec74e1c8a7acbe46256f92f_isInitialized(): async Bool {
        initialized;
    };

    // TODO: Join into a single var.
    stable var indirect_caller_: ?IndirectCaller.IndirectCaller = null;

    private func getIndirectCaller(): IndirectCaller.IndirectCaller {
        let ?indirect_caller_2 = indirect_caller_ else {
            Debug.trap("indirect_caller_ not initialized");
        };
        indirect_caller_2;
    };

    public shared({caller}) func setIndirectCaller(indirect_caller_v: IndirectCaller.IndirectCaller): async () {
        onlyOwner(caller);

        indirect_caller_ := ?indirect_caller_v;
    };

    stable var nextInstallationId: Nat = 1; // 0 is reserved for bootstrapper (HACK)

    stable var _installedPackagesSave: [(Common.InstallationId, Common.SharedInstalledPackageInfo)] = [];
    var installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo> =
        HashMap.HashMap(0, Nat.equal, Int.hash);

    stable var _installedPackagesByNameSave: [(Common.PackageName, [Common.InstallationId])] = [];
    var installedPackagesByName: HashMap.HashMap<Common.PackageName, [Common.InstallationId]> =
        HashMap.HashMap(0, Text.equal, Text.hash);

    stable var _halfInstalledPackagesSave: [(Common.InstallationId, {
        /// The number of modules in fully installed state.
        shouldHaveModules: Nat;
        name: Common.PackageName;
        version: Common.Version;
        modules: [Principal];
    })] = [];
    // TODO: `var` or `let` here and in other places:
    var halfInstalledPackages: HashMap.HashMap<Common.InstallationId, Common.HalfInstalledPackageInfo> =
        HashMap.fromIter([].vals(), 0, Nat.equal, Int.hash);

    stable var repositories: [{canister: Principal; name: Text}] = []; // TODO: a more suitable type like `HashMap` or at least `Buffer`?

    func onlyOwner(caller: Principal) {
        if (owners.get(caller) == null) {
            Debug.trap("not the owner");
        }
    };

    public shared({caller}) func installPackage({
        repo: RepositoryPartition.RepositoryPartition;
        packageName: Common.PackageName;
        version: Common.Version;
        callback: ?(shared ({ // TODO
            installationId: Common.InstallationId;
            can: Principal;
            // caller: Principal;
            package: Common.PackageInfo;
            data: Blob;
        }) -> async ());
    })
        : async {installationId: Common.InstallationId}
    {
        onlyOwner(caller);

        let installationId = nextInstallationId;
        nextInstallationId += 1;

        await* _installPackage({
            pmPrincipal = Principal.fromActor(this);
            caller;
            packageName;
            version;
            preinstalledModules = null;
            repo; // TODO: Pass it in `data` instead.
            installationId;
            callback;
            data = to_candid(());
        });
        {installationId};
    };

    public shared({caller}) func installPackageWithPreinstalledModules({
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: [(Text, Principal)];
        repo: Common.RepositoryPartitionRO;
        caller: Principal;
        installationId: Common.InstallationId;
        callback: ?(shared ({ // TODO
            // caller: Principal;
            can: Principal;
            installationId: Common.InstallationId;
            // indirectCaller: IndirectCaller.IndirectCaller;
            data: Blob;
        }) -> async ());
        data: Blob;
    })
        : async ()
    {
        Debug.print("installPackageWithPreinstalledModules"); // FIXME: Remove.
        onlyOwner(caller);

        Debug.print("Z1"); // FIXME: Remove.
        await* _installPackage({
            pmPrincipal = Principal.fromActor(this);
            caller;
            packageName;
            version;
            preinstalledModules = ?preinstalledModules;
            repo;
            installationId;
            callback = ?installPackageCallback;
            data = to_candid({ // FIXME
                firstCallback = callback;
                firstData = data;
            });
        });
    };

    /// We don't install dependencies here (see `specs.odt`).
    private func _installPackage({
        pmPrincipal: Principal;
        caller: Principal;
        packageName: Common.PackageName;
        version: Common.Version;
        preinstalledModules: ?[(Text, Principal)];
        repo: Common.RepositoryPartitionRO;
        installationId: Common.InstallationId;
        callback: ?(shared ({ // TODO
            installationId: Common.InstallationId;
            can: Principal;
            // caller: Principal;
            package: Common.PackageInfo;
            data: Blob;
        }) -> async ());
        data: Blob;
    })
        : async* () // TODO: Precreate and return canister IDs.
    {
        Debug.print("calling installPackageWrapper"); // FIXME: Remove.
        getIndirectCaller().installPackageWrapper({
            repo;
            pmPrincipal;
            packageName;
            version;
            installationId;
            preinstalledModules;
            callback;
            data = to_candid(()); // TODO: correct?
        });
    };

    public shared({caller}) func installPackageCallback({ // TODO
        installationId: Common.InstallationId;
        can: Principal;
        // caller: Principal;
        package: Common.PackageInfo;
        data: Blob;
    }): async () {
        Debug.print("installPackageCallback");

        let ?{firstData; firstCallback}: ?{
            firstData: Blob;
            firstCallback: ?(shared ({
                installationId: Common.InstallationId;
                can: Principal;
                caller: Principal;
                package: Common.PackageInfo;
                data: Blob;
            }) -> async ());
        } = from_candid(data) else {
            Debug.trap("programming error");
        };
        switch (firstCallback) {
            case (?firstCallback) {
                await firstCallback({installationId; can; caller; package; data = to_candid(())}); // FIXME: `data`
            };
            case null {};
        };

        let ?d: ?{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryPartitionRO;
            preinstalledModules: ?[(Text, Principal)];
        } = from_candid(firstData) else {
            Debug.trap("programming error")
        };

        let #real realPackage = package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };

        let numPackages = Array.size(realPackage.modules);
        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = numPackages;
            // id = installationId;
            name = package.base.name;
            version = package.base.version;
            modules = OrderedHashMap.OrderedHashMap<Text, (Principal, {#empty; #installed})>(numPackages, Text.equal, Text.hash);
            // packageDescriptionIn = part;
            package;
            packageCanister = Principal.fromActor(d.repo);
            preinstalledModules = d.preinstalledModules;
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        let installation: Common.InstalledPackageInfo = {
            id = installationId;
            name = d.packageName;
            package;
            packageCanister = Principal.fromActor(d.repo);
            version = d.version;
            modules = OrderedHashMap.OrderedHashMap<Text, Principal>(Array.size(realPackage.modules), Text.equal, Text.hash);
            // extraModules = Buffer.Buffer<(Text, Principal)>(Array.size(realPackage.extraModules));
            allModules = Buffer.Buffer<Principal>(0); // 0?
        };

        let IC: Common.CanisterCreator = actor("aaaaa-aa");

        // TODO: Also correctly create canisters if installation was interrupted.
        let canisterIds = Buffer.Buffer<(Text, Principal)>(realPackage.modules.size());
        // TODO: Don't wait for creation of a previous canister to create the next one.
        label create for ((moduleName, wasmModule) in realPackage.modules.vals()) {
            let created = Option.isSome(ourHalfInstalled.modules.get(moduleName));
            if (created) {
                continue create;
            };
            let canister_id = switch (d.preinstalledModules) {
                case (?preinstalledModules) {
                    // assert preinstalledModules.size() == realPackage.modules.size(); // TODO: correct?
                    let res = Iter.filter(
                        preinstalledModules.vals(),
                        func((n, _m): (Text, Principal)): Bool = n == moduleName,
                    ).next();
                    switch (res) {
                        case (?(_, canister_id)) canister_id;
                        case null { Debug.trap("programming error"); }; 
                    };                    
                };
                case null {
                    Cycles.add<system>(10_000_000_000_000);
                    let res = await cycles_ledger.create_canister({
                        amount = 0; // FIXME
                        created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
                        creation_args = ?{
                            settings = ?{
                                freezing_threshold = null; // TODO: 30 days may be not enough, make configurable.
                                controllers = ?[Principal.fromActor(getIndirectCaller())]; // No package manager as a controller, because the PM may be upgraded.
                                compute_allocation = null; // TODO
                                memory_allocation = null; // TODO (a low priority task)
                            };
                            subnet_selection = null;
                        };
                        from_subaccount = null; // FIXME
                    });
                    let canister_id = switch (res) {
                        case (#Ok {canister_id}) canister_id;
                        case (#Err err) {
                            let msg = debug_show(err);
                            Debug.print("cannot create canister: " # msg);
                            Debug.trap("cannot create canister: " # msg);
                        };
                    };
                    canister_id;
                };
            };
            // TODO: Are two lines below duplicates of each other?
            ourHalfInstalled.modules.put(moduleName, (canister_id, #empty));
            canisterIds.add((moduleName, canister_id)); // do it later.
        };
        installedPackages.put(installationId, installation);

        await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
            preinstalledModules = switch(ourHalfInstalled.preinstalledModules) {
                case (?preinstalledModules) {
                    ?(HashMap.fromIter<Text, Principal>(preinstalledModules.vals(), preinstalledModules.size(), Text.equal, Text.hash));
                };
                case null null;
            };
        });
    };  

    /// Finish installation of a half-installed package.
    public shared({caller}) func finishInstallPackage({
        installationId: Nat;
    }): async () {
        onlyOwner(caller);
        
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        let #real realPackage = ourHalfInstalled.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        await* _finishInstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
            caller;
        });
    };

    // TODO: Keep registry of ALL installed modules.
    private func _finishInstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
        caller: Principal; // TODO: Rename to `user`.
    }): async* () {
        label install for ((moduleName, wasmModule) in realPackage.modules.vals()) {
            let ?state = ourHalfInstalled.modules.get(moduleName) else {
                Debug.trap("programming error");
            };
            if (state.1 == #installed) {
                continue install;
            };
            let installArg = to_candid({
                arg = to_candid({}); // TODO: correct?
            });
            if (Option.isNull(ourHalfInstalled.preinstalledModules)) {
                // FIXME: `canister` is `()`.
                let canister = await* _installModule(wasmModule, to_candid(()), ?installArg, getIndirectCaller(), Principal.fromActor(this), installationId, installedPackages, caller);
            }/* else {
                // We don't need to initialize installed module, because it can be only
                // PM's frontend.
            }*/;
        };

        _updateAfterInstall({installationId});
    };

    private func _installModule(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManager: Principal,
        installation: Common.InstallationId,
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>, // FIXME: not here
        user: Principal,
    ): async* () {
        ignore await* Install._installModuleButDontRegister({
            wasmModule;
            installArg;
            initArg;
            indirectCaller;
            packageManagerOrBootstrapper = packageManager;
            user;
            callback = ?installModuleCallback;
            data = to_candid({/*installedPackages*/}); // FIXME: Ship package info.
        });
    };

    public shared({caller}) func installModuleCallback({
        can: Principal;
        installationId: Common.InstallationId;
        indirectCaller: IndirectCaller.IndirectCaller; // TODO: Rename.
        packageManagerOrBootstrapper: Principal;
        data: Blob;
    }) : async () {
        if (caller != Principal.fromActor(getIndirectCaller())) { // TODO
            Debug.trap("callback not by indirect_caller");
        };

        let ?{/*installedPackages*/}: ?{/*installedPackages: */} = from_candid(data) else {
            Debug.trap("programming error");
        };
        await* Install._registerModule({installation = installationId; canister = can; packageManager = packageManagerOrBootstrapper; installedPackages}); // FIXME: Is one-way function above finished?
    };

    private func _updateAfterInstall({installationId: Common.InstallationId}) {
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package installation has not been started");
        };
        installedPackages.put(installationId, {
            id = installationId;
            name = ourHalfInstalled.name;
            package = ourHalfInstalled.package;
            version = ourHalfInstalled.package.base.version; // TODO: needed?
            modules = OrderedHashMap.fromIter(Iter.map<(Text, (Principal, {#empty; #installed})), (Text, Principal)>(
                ourHalfInstalled.modules.entries(),
                func ((x, (y, z)): (Text, (Principal, {#empty; #installed}))) = (x, y),
            ), ourHalfInstalled.modules.size(), Text.equal, Text.hash);
            packageCanister = ourHalfInstalled.packageCanister;
            // extraModules = Buffer.Buffer<Principal>(0);
            allModules = Buffer.Buffer<Principal>(0);
        });
        halfInstalledPackages.delete(installationId);
        switch (installedPackagesByName.get(ourHalfInstalled.package.base.name)) {
            case (?ids) {
                installedPackagesByName.put(ourHalfInstalled.package.base.name, Array.append(ids, [installationId]));
            };
            case null {
                installedPackagesByName.put(ourHalfInstalled.package.base.name, [installationId]);
            };
        };
    };

    /// Intended to use only in bootstrapping.
    ///
    /// TODO: Should we disable calling this after bootstrapping finished?
    // public shared({caller}) func installModule(wasmModule: Common.Module, installArg: Blob, initArg: ?Blob): async Principal {
    //     onlyOwner(caller);

    //     await* Install._installModule(wasmModule, installArg, initArg, getIndirectCaller(), Principal.fromActor(this));
    // };

    /// It can be used directly from frontend.
    ///
    /// `avoidRepeated` forbids to install them same named modules more than once.
    /// TODO: What if, due actor model's non-reability, it installed partially.
    public shared({caller}) func installNamedModules(
        installationId: Common.InstallationId,
        modules: [(Text, Blob, ?Blob)], // name, installArg, initArg
        avoidRepeated: Bool,
    ): async () {
        onlyOwner(caller);

        let ?installation = installedPackages.get(installationId) else {
            Debug.trap("no such package");
        };
        let package = installation.package;

        // TODO: Don't install already installed.
        let modules0 = Iter.map<(Text, Blob, ?Blob), (Text, (Blob, ?Blob))>(
            modules.vals(),
            func(x: (Text, Blob, ?Blob)): (Text, (Blob, ?Blob)) = (x.0, (x.1, x.2)));
        let modules2 = HashMap.fromIter<Text, (Blob, ?Blob)>(modules0, Array.size(modules), Text.equal, Text.hash);
        switch (package.specific) {
            case (#real package) {
                let extraModules2 = HashMap.fromIter<Text, Common.Module>(package.extraModules.vals(), Array.size(modules), Text.equal, Text.hash);
                for (m in modules0) {
                    let ?wasmModule = extraModules2.get(m.0) else {
                        Debug.trap("no extra module '" # m.0 # "'");
                    };
                    let ?(installArg, initArg) = modules2.get(m.0) else {
                        Debug.trap("programming error");
                    };
                    ignore await* _installNamedModule(wasmModule, installArg, initArg, getIndirectCaller(), Principal.fromActor(this), installationId, m.0, installedPackages, caller);
                };
                if (avoidRepeated) {
                    // TODO: wrong condition
                    // if (iter.next() != null) {
                    //     Debug.trap("repeated install");
                    // };
                };
            };
            case (#virtual _) {
                Debug.trap("cannot install modules on a virtual package");
            };
        };
    };

    private func _installNamedModule(
        wasmModule: Common.Module,
        installArg: Blob,
        initArg: ?Blob, // init is optional
        indirectCaller: IndirectCaller.IndirectCaller,
        packageManager: Principal,
        installation: Common.InstallationId,
        moduleName: Text,
        installedPackages: HashMap.HashMap<Common.InstallationId, Common.InstalledPackageInfo>, // TODO: not here
        user: Principal,
   ): async* () {
        ignore await* Install._installModuleButDontRegister({
            wasmModule;
            installArg;
            initArg;
            indirectCaller;
            packageManagerOrBootstrapper = packageManager;
            user;
            callback = ?installNamedModuleCallback;
            data = to_candid({moduleName});
        });
    };

    public shared({caller}) func installNamedModuleCallback({
        can: Principal;
        installationId: Common.InstallationId;
        packageManagerOrBootstrapper: Principal;
        indirectCaller: IndirectCaller.IndirectCaller;
        data: Blob;
    }): async () {
        if (caller != Principal.fromActor(getIndirectCaller())) { // TODO
            Debug.trap("callback not by indirect_caller");
        };

        let ?{moduleName}: ?{moduleName: Text} = from_candid(data) else {
            Debug.trap("programming error");
        };
        await* Install._registerNamedModule({
            installation = installationId;
            canister = can;
            packageManager = packageManagerOrBootstrapper; // TODO: correct `OrBootstrapper`?
            moduleName;
            installedPackages;
        });
    };
        
    public shared({caller}) func uninstallPackage(installationId: Common.InstallationId)
        : async ()
    {
        onlyOwner(caller);

        let ?installation = installedPackages.get(installationId) else {
            Debug.trap("no such installed installation");
        };
        let part: RepositoryPartition.RepositoryPartition = actor (Principal.toText(installation.packageCanister));
        let packageInfo = await part.getPackage(installation.name, installation.version);

        let ourHalfInstalled: Common.HalfInstalledPackageInfo = {
            shouldHaveModules = installation.modules.size(); // TODO: Is it a nonsense?
            name = installation.name;
            version = installation.version;
            modules = OrderedHashMap.fromIter( // TODO: can be made simpler?
                Iter.map<(Text, Principal), (Text, (Principal, {#empty; #installed}))>(
                    installation.modules.entries(),
                    func ((x, y): (Text, Principal)) = (x, (y, #installed))
                ),                
                installation.modules.size(),
                Text.equal,
                Text.hash,
            );
            package = packageInfo;
            packageCanister = installation.packageCanister;
            preinstalledModules = null; // TODO: Seems right, but check again.
        };
        halfInstalledPackages.put(installationId, ourHalfInstalled);

        // TODO:
        // let part: Common.RepositoryPartitionRO = actor (Principal.toText(canister));
        // let installation = await part.getPackage(packageName, version);
        let #real realPackage = packageInfo.specific else {
            Debug.trap("trying to directly install a virtual installation");
        };

        await* _finishUninstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
        });
    };

    type CanisterDeletor = actor {
        stop_canister : shared { canister_id : Common.canister_id } -> async ();
        delete_canister : shared { canister_id : Common.canister_id } -> async ();
    };

    private func _finishUninstallPackage({
        installationId: Nat;
        ourHalfInstalled: Common.HalfInstalledPackageInfo;
        realPackage: Common.RealPackageInfo;
    }): async* () {
        let IC: CanisterDeletor = actor("aaaaa-aa");
        while (ourHalfInstalled.modules.size() != 0) {
            let vals = Iter.toArray(ourHalfInstalled.modules.vals()); // TODO: slow
            let canister_id = vals[vals.size() - 1].0;
            getIndirectCaller().callAllOneWay([
                {
                    canister = Principal.fromActor(IC);
                    name = "stop_canister";
                    data = to_candid({canister_id});
                },
                {
                    canister = Principal.fromActor(IC);
                    name = "delete_canister";
                    data = to_candid({canister_id});
                },
            ]);
            ignore ourHalfInstalled.modules.removeLast();
        };
        installedPackages.delete(installationId);
        let ?byName = installedPackagesByName.get(ourHalfInstalled.name) else {
            Debug.trap("programming error");
        };
        // TODO: The below is inefficient and silly, need to change data structure?
        if (Array.size(byName) == 1) {
            installedPackagesByName.delete(ourHalfInstalled.name);
        } else {
            let new = Iter.filter(byName.vals(), func (e: Common.InstallationId): Bool {
                e != installationId;
            });
            installedPackagesByName.put(ourHalfInstalled.name, Iter.toArray(new));
        };
        halfInstalledPackages.delete(installationId);
    };

     /// Finish installation of a half-installed package.
    public shared({caller}) func finishUninstallPackage({installationId: Nat}): async () {
        onlyOwner(caller);
        
        let ?ourHalfInstalled = halfInstalledPackages.get(installationId) else {
            Debug.trap("package uninstallation has not been started");
        };
        let #real realPackage = ourHalfInstalled.package.specific else {
            Debug.trap("trying to directly install a virtual package");
        };
        await* _finishUninstallPackage({
            installationId;
            ourHalfInstalled;
            realPackage;
        });
    };

   system func preupgrade() {
        _ownersSave := Iter.toArray(owners.entries());

        _installedPackagesSave := Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(installedPackages.entries(), func ((id, info): (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) {
                (id, Common.installedPackageInfoShare(info));
            }
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

        installedPackages := HashMap.fromIter<Common.InstallationId, Common.InstalledPackageInfo>(
            Iter.map<(Common.InstallationId, Common.SharedInstalledPackageInfo), (Common.InstallationId, Common.InstalledPackageInfo)>(
                _installedPackagesSave.vals(),
                func ((id, info): (Common.InstallationId, Common.SharedInstalledPackageInfo)): (Common.InstallationId, Common.InstalledPackageInfo) {
                    (id, Common.installedPackageInfoUnshare(info));
                },
            ),Array.size(_installedPackagesSave),
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

    // Accessor method //

    public query func getInstalledPackage(id: Common.InstallationId): async Common.SharedInstalledPackageInfo {
        let ?result = installedPackages.get(id) else {
            Debug.trap("no such installed package");
        };
        Common.installedPackageInfoShare(result);
    };

    /// TODO: very unstable API.
    public query func getInstalledPackagesInfoByName(name: Text): async [Common.SharedInstalledPackageInfo] {
        let ?ids = installedPackagesByName.get(name) else {
            return [];
        };
        // TODO: Eliminiate duplicate code:
        Iter.toArray(Iter.map(ids.vals(), func (id: Common.InstallationId): Common.SharedInstalledPackageInfo {
            let ?info = installedPackages.get(id) else {
                Debug.trap("programming error");
            };
            Common.installedPackageInfoShare(info);
        }));
    };

    /// TODO: very unstable API.
    public query func getAllInstalledPackages(): async [(Common.InstallationId, Common.SharedInstalledPackageInfo)] {
        Iter.toArray(
            Iter.map<(Common.InstallationId, Common.InstalledPackageInfo), (Common.InstallationId, Common.SharedInstalledPackageInfo)>(
                installedPackages.entries(),
                func (info: (Common.InstallationId, Common.InstalledPackageInfo)): (Common.InstallationId, Common.SharedInstalledPackageInfo) =
                    (info.0, Common.installedPackageInfoShare(info.1))
            )
        );
    };

    /// TODO: very unstable API.
    public query func getHalfInstalledPackages(): async [{
        installationId: Common.InstallationId;
        packageCanister: Principal;
        name: Common.PackageName;
        version: Common.Version;
    }] {
        Iter.toArray(Iter.map<(Common.InstallationId, Common.HalfInstalledPackageInfo), {
            installationId: Common.InstallationId;
            packageCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        }>(halfInstalledPackages.entries(), func (x: (Common.InstallationId, Common.HalfInstalledPackageInfo)): {
            installationId: Common.InstallationId;
            packageCanister: Principal;
            name: Common.PackageName;
            version: Common.Version;
        } =
            {
                installationId = x.0;
                packageCanister = x.1.packageCanister;
                name = x.1.name;
                version = x.1.version;
            },
        ));
    };

    /// TODO: very unstable API.
    public query func getHalfInstalledPackageById(installationId: Common.InstallationId): async {
        packageName: Text;
        version: Common.Version;
        package: Common.PackageInfo;
    } {
        let ?res = halfInstalledPackages.get(installationId) else {
            Debug.trap("no such package")
        };
        {packageName = res.name; version = res.version; package = res.package};
    };

    // TODO: Copy package specs to "userspace", in order to have `extraModules` fixed for further use.

    // Convenience methods //

    public shared({caller}) func addRepository(canister: Principal, name: Text): async () {
        onlyOwner(caller);

        repositories := Array.append(repositories, [{canister; name}]); // TODO: Use `Buffer` instead.
    };

    public shared({caller}) func removeRepository(canister: Principal): async () {
        onlyOwner(caller);

        repositories := Iter.toArray(Iter.filter(
            repositories.vals(),
            func (x: {canister: Principal; name: Text}): Bool = x.canister != canister));
    };

    public query func getRepositories(): async [{canister: Principal; name: Text}] {
        repositories;
    };

    public shared({caller}) func registerNamedModule({
        installation: Common.InstallationId;
        canister: Principal;
        packageManager: Principal;
        moduleName: Text;
    }): async () {
        onlyOwner(caller);

        await* Install._registerNamedModule({
            installation;
            canister;
            packageManager;
            moduleName;
            installedPackages; // TODO: not here
        });
    };

    public shared({caller})  func createInstaallation(): async Common.InstallationId {
        onlyOwner(caller);

        let installationId = nextInstallationId;
        nextInstallationId += 1;
        installationId;
    }
}