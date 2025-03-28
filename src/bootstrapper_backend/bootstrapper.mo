/// This module is legible to non-returning-function attack. Throw it away if it fails this way.
/// Data is stored in `bootstrapper_data` instead.
import Asset "mo:assets-api";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";
import Cycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import env "mo:env";
import CyclesLedger "canister:cycles_ledger";
import Data "canister:bootstrapper_data";
import Repository "canister:repository";

actor class Bootstrapper() = this {
    /// `cyclesAmount` is the total cycles amount, including canister creation fee.
    /*stable*/ var newCanisterCycles = 1000_000_000_000_000; // TODO: Edit it. (Move to `bootstrapper_data`?)

    /// Both frontend and backend boootstrapping should fit this. Should be given with a reserve.
    var totalBootstrapCost = 10_000_000_000_000; // TODO: Make it stable.

    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    public shared({caller = user}) func bootstrapFrontend({
        installArg: Blob;
        frontendTweakPubKey: PubKey;
    }): async {canister_id: Principal} {
        // TODO: Check if the user paid enough cycles.
        let amountToMove = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(Principal.toBlob(user));
        });

        // Move user's fund into current use:
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = Principal.fromActor(this); subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Principal.toBlob(user));
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = amountToMove;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };

        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );
        let ?wasmModule = modulesToInstall.get("frontend") else {
            Debug.trap("frontend module not found");
        };
        Cycles.add<system>(amountToMove);
        let {canister_id} = await* Install.myCreateCanister({
            controllers = ?[Principal.fromActor(this)];
            cyclesAmount = newCanisterCycles;
            subnet_selection = ?(
                #Filter({subnet_type = ?"Application"})
            );
        });

        Cycles.add<system>(Cycles.refunded());
        await* Install.myInstallCode({
            installationId = 0;
            upgradeId = null;
            canister_id;
            wasmModule = Common.unshareModule(wasmModule);
            installArg;
            packageManagerOrBootstrapper = Principal.fromActor(this); // modified by frontend tweak below.
            // Automated tests esnure that these `aaaaa-aa` don't appear at a later installation stage:
            mainIndirect = Principal.fromText("aaaaa-aa");
            simpleIndirect = Principal.fromText("aaaaa-aa");
            user;
        });
        Cycles.add<system>(Cycles.refunded());
        await Data.putFrontendTweaker(canister_id, frontendTweakPubKey);

        // Return user's fund from current use:
        ignore await CyclesLedger.icrc1_transfer({ // TODO: Not `ignore`.
            to = {owner = Principal.fromActor(this); subaccount = ?(Principal.toBlob(user))};
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = Cycles.refunded();
        });

        {canister_id};
    };

    /// Installs the backend after frontend is already installed, tweaks frontend.
    ///
    /// We don't allow to substitute user-chosen modules for the package manager itself,
    /// because it would be a security risk of draining cycles.
    public shared({caller = user}) func bootstrapBackend({
        packageManagerOrBootstrapper: Principal;
        frontend: Principal;
        frontendTweakPrivKey: PrivKey;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async {
        installedModules: [(Text, Principal)];
    } {
        let amountToMove = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(Principal.toBlob(user));
        });

        // Move user's fund into current use:
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = Principal.fromActor(this); subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Principal.toBlob(user));
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = amountToMove;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };

        Cycles.add<system>(amountToMove);
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        // We bootstrap backend at this stage:
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            Iter.filter<(Text, Common.SharedModule)>(
                icPackPkgReal.modules.vals(), func (name: Text, _: Common.SharedModule) = name != "frontend"
            ),
            icPackPkgReal.modules.size() - 1,
            Text.equal,
            Text.hash,
        );
        await* bootstrapBackendImpl({
            modulesToInstall;
            user;
            packageManagerOrBootstrapper;
            frontend;
            frontendTweakPrivKey;
            additionalPackages;
        });

        // We don't do transfer to the user here, because in `bootstrapBackendImpl` we already tranferred to the battery.
    };

    private func bootstrapBackendImpl({
        modulesToInstall: HashMap.HashMap<Text, Common.SharedModule>;
        user: Principal;
        packageManagerOrBootstrapper: Principal;
        frontend: Principal;
        frontendTweakPrivKey: PrivKey;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async* {
        installedModules: [(Text, Principal)];
    } {
        let installedModules = HashMap.HashMap<Text, Principal>(modulesToInstall.size(), Text.equal, Text.hash);
        for (moduleName in modulesToInstall.keys()) {
            Cycles.add<system>(Cycles.refunded());
            let {canister_id} = await* Install.myCreateCanister({
                controllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
                cyclesAmount = newCanisterCycles;
                subnet_selection = ?(
                    #Filter({subnet_type = ?"Application"})
                );
            });
            installedModules.put(moduleName, canister_id);
        };
        let ?backend = installedModules.get("backend") else {
            Debug.trap("module not deployed");
        };
        let ?mainIndirect = installedModules.get("main_indirect") else {
            Debug.trap("module not deployed");
        };
        let ?simpleIndirect = installedModules.get("simple_indirect") else {
            Debug.trap("module not deployed");
        };
        let ?battery = installedModules.get("battery") else {
            Debug.trap("module not deployed");
        };
        for ((moduleName, canister_id) in installedModules.entries()) {
            let ?m = modulesToInstall.get(moduleName) else {
                Debug.trap("module not found");
            };
            Cycles.add<system>(Cycles.refunded());
            await* Install.myInstallCode({
                installationId = 0;
                upgradeId = null;
                canister_id;
                wasmModule = Common.unshareModule(m);
                installArg = to_candid({});
                packageManagerOrBootstrapper = if (moduleName == "backend") {
                    packageManagerOrBootstrapper // to call `installPackageWithPreinstalledModules` below
                } else {
                    backend
                };
                mainIndirect;
                simpleIndirect;
                user;
                // TODO: Pass the following only to the `backend` module:
                // frontend;
                // frontendTweakPrivKey;
                // repo = Repository;
                // additionalPackages;
            });
        };

        let controllers = [simpleIndirect, mainIndirect, backend, user];

        for (canister_id in installedModules.vals()) { // including frontend
            // TODO: We can provide these setting initially and thus update just one canister.
            Cycles.add<system>(Cycles.refunded());
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = {
                    compute_allocation = null;
                    // `indirect_canister_id` here is only for the package manager package:
                    controllers = ?controllers;
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

        let backendActor = actor(Principal.toText(backend)): actor {
            installPackageWithPreinstalledModules: shared ({
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryRO; 
                user: Principal;
                mainIndirect: Principal;
                /// Additional packages to install after bootstrapping.
                additionalPackages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryRO;
                }];
                preinstalledModules: [(Text, Principal)];
            }) -> async {minInstallationId: Common.InstallationId};
        };
        // TODO: Transfer user cycles before this call:
        Cycles.add<system>(Cycles.refunded());
        ignore await backendActor.installPackageWithPreinstalledModules({
          whatToInstall = #package;
          packageName = "icpack";
          version = "stable";
          preinstalledModules = Iter.toArray(installedModules.entries());
          repo = Repository;
          user;
          mainIndirect;
          additionalPackages;
        });

        // TODO: `ignore` here?
        ignore await CyclesLedger.icrc1_transfer({
            to = {owner = battery; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = totalBootstrapCost;
        });

        // the last stage of installation, not to add failed bookmark:
        await* tweakFrontend(frontend, frontendTweakPrivKey, controllers);

        // TODO: Make adding a bookmark optional. (Or else, remove frontend bookmarking code.)
        //       For this, make the private key a part of the persistent link arguments?
        //       Need to ensure that the link is paid for (prevent DoS attacks).
        //       Another (easy) way is to add "Bookmark" checkbox to bootstrap.
        //       It seems that there is an easy solution: Leave a part of the paid sum on the account to pay for bookmark.
        // Cycles.add<system>(env.bookmarkCost);
        // ignore await Bookmarks.addBookmark({frontend; backend}, user);

        { installedModules = Iter.toArray(installedModules.entries()); }
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Internal. Updates controllers and owners of the frontend.
    ///
    /// TODO: Rename.
    private func tweakFrontend(
        frontend: Principal,
        privKey: PrivKey,
        controllers: [Principal],
    ): async* () {
        Cycles.add<system>(Cycles.refunded());
        let pubKey = await Data.getFrontendTweaker(frontend);
        if (Sha256.fromBlob(#sha256, privKey) != pubKey) {
            Debug.trap("access denied");
        };
        let assets: Asset.AssetCanister = actor(Principal.toText(frontend));
        Cycles.add<system>(Cycles.refunded());
        let owners = await assets.list_authorized();
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            // TODO: `user` here is a bootstrapper user, not backend user. // TODO: Add backend user.
            for (principal in controllers.vals()) {
                Cycles.add<system>(Cycles.refunded());
                await assets.grant_permission({to_principal = principal; permission});
            };
            for (owner in owners.vals()) {
                Cycles.add<system>(Cycles.refunded());
                await assets.revoke_permission({
                    of_principal = owner; // TODO: Why isn't it enough to remove `Principal.fromActor(this)`?
                    permission;
                });
            };
        };
        // Done above:
        // await ic.update_settings({
        //     canister_id = frontend;
        //     sender_canister_version = null;
        //     settings = {
        //         compute_allocation = null;
        //         // We don't include `indirect_canister_id` because it can't control without risk of ite beiing replaced.
        //         // I don't add more controllers, because controlling this is potentially unsafe.
        //         controllers = ?[backend_canister_id, indirect_canister_id, simple_indirect_canister_id, frontend];
        //         freezing_threshold = null;
        //         log_visibility = null;
        //         memory_allocation = null;
        //         reserved_cycles_limit = null;
        //         wasm_memory_limit = null;
        //     };
        // });
        Cycles.add<system>(Cycles.refunded());
        await Data.deleteFrontendTweaker(frontend);
    };
}