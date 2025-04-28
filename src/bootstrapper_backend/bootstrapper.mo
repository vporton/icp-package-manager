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
import Float "mo:base/Float";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import env "mo:env";
import CyclesLedger "canister:cycles_ledger";
import Data "canister:bootstrapper_data";
import Repository "canister:repository";
import Bookmarks "canister:bookmark";

actor class Bootstrapper() = this {
    transient let cycles_transfer_fee = 100_000_000_000;

    /// `cyclesAmount` is the total cycles amount, including canister creation fee.
    transient let newCanisterCycles = 2_000_000_000_000; // TODO@P3: Make it editable (move to `bootstrapper_data`).

    transient let revenueRecipient = Principal.fromText(env.revenueRecipient);

    private func principalToSubaccount(principal : Principal) : Blob {
        var sub = Buffer.Buffer<Nat8>(32);
        let subaccount_blob = Principal.toBlob(principal);

        sub.add(Nat8.fromNat(subaccount_blob.size()));
        sub.append(Buffer.fromArray<Nat8>(Blob.toArray(subaccount_blob)));
        while (sub.size() < 32) {
            sub.add(0);
        };

        Blob.fromArray(Buffer.toArray(sub));
    };

    /// TODO@P3: Do we need this check?
    private func checkItself(caller: Principal) {
        if (caller != Principal.fromActor(this)) {
            Debug.trap("can be called only by itself");
        };
    };

    public shared({caller}) func doBootstrapFrontend(frontendTweakPubKey: PubKey, user: Principal, amountToMove: Nat)
        : async {installedModules: [(Text, Principal)]}
    {
        checkItself(caller);

        // ignore Cycles.accept<system>(amountToMove);
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );

        let installedModules = HashMap.HashMap<Text, Principal>(modulesToInstall.size(), Text.equal, Text.hash);
        for (moduleName in modulesToInstall.keys()) {
            let cyclesAmount = if (moduleName == "main_indirect") {
                    20_000_000_000_000 // TODO@P2: It can be reduced to 2_000_000_000_000 for UI, but auto-test requires more.
                } else {
                    newCanisterCycles;
                };
            ignore Cycles.accept<system>(cyclesAmount);
            let {canister_id} = await* Install.myCreateCanister({
                controllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
                cyclesAmount;
                subnet_selection = ?(
                    #Filter({subnet_type = ?"Application"})
                );
            });
            installedModules.put(moduleName, canister_id);
        };

        let ?frontend = installedModules.get("frontend") else {
            Debug.trap("module not deployed");
        };
        let ?backend = installedModules.get("backend") else {
            Debug.trap("module not deployed");
        };
        // let ?mainIndirect = installedModules.get("main_indirect") else {
        //     Debug.trap("module not deployed");
        // };
        let ?simpleIndirect = installedModules.get("simple_indirect") else {
            Debug.trap("module not deployed");
        };
        let ?battery = installedModules.get("battery") else {
            Debug.trap("module not deployed");
        };

        let ?mFrontend = modulesToInstall.get("frontend") else {
            Debug.trap("module not found");
        };
        let wasmModuleLocation = Common.extractModuleLocation(mFrontend.code);
        await ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({});
            wasm_module = await Repository.getWasmModule(wasmModuleLocation.1);
            mode = #install;
            canister_id = frontend;
            sender_canister_version = null; // TODO@P3
        });
        await* Install.copyAssetsIfAny({
            wasmModule = Common.unshareModule(mFrontend);
            canister_id = frontend;
            simpleIndirect;
            user;
        });

        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        await Data.putFrontendTweaker(frontendTweakPubKey, {
            frontend;
            user;
        });

        // TODO@P3: Make adding a bookmark optional. (Or else, remove frontend bookmarking code.)
        //          For this, make the private key a part of the persistent link arguments?
        //          Need to ensure that the link is paid for (prevent DoS attacks).
        //          Another (easy) way is to add "Bookmark" checkbox to bootstrap.
        //          It seems that there is an easy solution: Leave a part of the paid sum on the account to pay for bookmark.
        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        ignore await Bookmarks.addBookmark({b = {frontend; backend}; battery; user});

        {installedModules = Iter.toArray(installedModules.entries())};
    };

    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    public shared({caller = user}) func bootstrapFrontend({
        frontendTweakPubKey: PubKey;
    }): async {installedModules: [(Text, Principal)]; spentCycles: Nat} {
        let amountToMove = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(principalToSubaccount(user));
        });

        // TODO@P3: `- 5*cycles_transfer_fee` and likewise seems to have superfluous multipliers.

        // Move user's fund into current use:
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = Principal.fromActor(this); subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(principalToSubaccount(user));
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = Int.abs(Float.toInt(Float.fromInt(amountToMove) * (1.0 - env.revenueShare))) - 5*cycles_transfer_fee;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(principalToSubaccount(user));
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = Int.abs(Float.toInt(Float.fromInt(amountToMove) * env.revenueShare)) - 4*cycles_transfer_fee;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };

        func finish(): async* {returnAmount: Nat} {
            Debug.print("Refunding user " # debug_show(Cycles.refunded())); // FIXME: Remove.
            let returnAmount = Int.abs(Cycles.refunded() - 3*cycles_transfer_fee);
            Debug.print("Transfer back: " # debug_show(returnAmount)); // FIXME: Remove.
            // Return user's fund from current use:
            switch(await CyclesLedger.icrc1_transfer({
                to = {owner = Principal.fromActor(this); subaccount = ?(principalToSubaccount(user))};
                fee = null;
                memo = null;
                from_subaccount = null;
                created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
                amount = returnAmount;
            })) {
                case (#Err e) {
                    Debug.trap("transfer failed: " # debug_show(e));
                };
                case (#Ok _) {};
            };
            {returnAmount};
        };

        let {installedModules} = try {
            Cycles.add<system>(amountToMove);
            await doBootstrapFrontend(frontendTweakPubKey, user, amountToMove);
        }
        catch (e) {
            ignore await* finish(); // After frontend install, we return the money, to continue with backend install.
            Debug.trap(Error.message(e));
        };
        let {returnAmount: Nat} = await* finish();

        {installedModules; spentCycles = amountToMove - returnAmount};
    };

    /// Installs the backend after frontend is already installed, tweaks frontend.
    ///
    /// We don't allow to substitute user-chosen modules for the package manager itself,
    /// because it would be a security risk of draining cycles.
    public shared func bootstrapBackend({
        frontendTweakPrivKey: PrivKey; // TODO@P3: Rename.
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabulities, used only to add as a controller.
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
            arg: Blob;
            initArg: ?Blob;
        }];
    }): async {spentCycles: Nat} {
        let pubKey = Sha256.fromBlob(#sha256, frontendTweakPrivKey);

        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        let tweaker = await Data.getFrontendTweaker(pubKey);

        let amountToMove = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(principalToSubaccount(tweaker.user));
        });

        // Move user's fund into current use:
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = Principal.fromActor(this); subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(principalToSubaccount(tweaker.user));
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = amountToMove - 2*cycles_transfer_fee;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };

        Cycles.add<system>(amountToMove);
        // We can't `try` on this, because if it fails, we don't know the battery.
        // TODO@P3: `try` to return money back to user account.
        let {battery} = await doBootstrapBackend({
            pubKey;
            installedModules;
            user;
            additionalPackages;
            amountToMove;
            tweaker
        });

        let returnAmount = Int.abs(Cycles.refunded() - 3*cycles_transfer_fee);

        ignore await CyclesLedger.icrc1_transfer({
            to = {owner = battery; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = null;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = returnAmount;
        });

        {spentCycles = amountToMove - returnAmount};
    };

    public shared({caller}) func doBootstrapBackend({
        pubKey: PubKey;
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabulities, used only to add as a controller.
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
            arg: Blob;
            initArg: ?Blob;
        }];
        amountToMove: Nat;
        tweaker: Data.FrontendTweaker;
    }): async {battery: Principal} {
        checkItself(caller);

        Cycles.add<system>(amountToMove);

        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };

        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );

        // We bootstrap backend at this stage:
        let installedModules2 = HashMap.fromIter<Text, Principal>(
            installedModules.vals(), installedModules.size(), Text.equal, Text.hash);
        let ?backend = installedModules2.get("backend") else {
            Debug.trap("module not deployed");
        };
        let ?mainIndirect = installedModules2.get("main_indirect") else {
            Debug.trap("module not deployed");
        };
        let ?simpleIndirect = installedModules2.get("simple_indirect") else {
            Debug.trap("module not deployed");
        };
        let ?battery = installedModules2.get("battery") else {
            Debug.trap("module not deployed");
        };

        label install for ((moduleName, canister_id) in installedModules.vals()) {
            if (moduleName == "frontend") {
                continue install;
            };
            let ?m = modulesToInstall.get(moduleName) else {
                Debug.trap("module not found");
            };
            Cycles.add<system>(1_000_000_000_000);
            await* Install.myInstallCode({
                installationId = 0;
                upgradeId = null;
                canister_id;
                wasmModule = Common.unshareModule(m);
                arg = to_candid({});
                packageManager = if (moduleName == "backend") {
                    Principal.fromActor(this) // to call `installPackageWithPreinstalledModules` below
                } else {
                    backend
                };
                mainIndirect;
                simpleIndirect;
                battery;
                user;
                // TODO@P3: Pass the following only to the `backend` module:
                // frontend;
                // frontendTweakPrivKey;
                // repo = Repository;
                // additionalPackages;
            });
        };

        let controllers = [simpleIndirect, mainIndirect, backend, battery, user]; // TODO@P3: duplicate code

        // TODO@P3: It may happen when the app is not installed because of an error.
        // the last stage of installation, not to add failed bookmark:
        await* tweakFrontend(tweaker, controllers, user);

        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        await Data.deleteFrontendTweaker(pubKey);

        for (canister_id in installedModules2.vals()) { // including frontend
            // TODO@P3: We can provide these setting initially and thus update just one canister.
            Cycles.add<system>(Cycles.balance() - 500_000_000_000);
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = { // TODO@P3
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
                arg: Blob;
                initArg: ?Blob;
                user: Principal;
                mainIndirect: Principal;
                /// Additional packages to install after bootstrapping.
                additionalPackages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryRO;
                    arg: Blob;
                    initArg: ?Blob;
                }];
                preinstalledModules: [(Text, Principal)];
            }) -> async {minInstallationId: Common.InstallationId};
        };
        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        ignore await backendActor.installPackageWithPreinstalledModules({
          packageName = "icpack";
          version = "stable";
          preinstalledModules = Iter.toArray(installedModules.vals());
          repo = Repository;
          arg = "";
          initArg = null;
          user;
          mainIndirect;
          additionalPackages;
        });

        {battery};
    };

    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Internal. Updates controllers and owners of the frontend.
    ///
    /// TODO@P3: Rename.
    private func tweakFrontend(
        tweaker: Data.FrontendTweaker,
        controllers: [Principal],
        user: Principal, // to address security vulnerabulities, used only to add a controller.
    ): async* () {
        let assets: Asset.AssetCanister = actor(Principal.toText(tweaker.frontend));
        Cycles.add<system>(Cycles.balance() - 500_000_000_000);
        let owners = await assets.list_authorized();
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            for (owner in owners.vals()) {
                Cycles.add<system>(Cycles.balance() - 500_000_000_000);
                await assets.revoke_permission({
                    of_principal = owner; // TODO@P3: Why isn't it enough to remove `Principal.fromActor(this)`?
                    permission;
                });
            };
            for (principal in Iter.concat(controllers.vals(), [user].vals())) {
                Cycles.add<system>(Cycles.balance() - 500_000_000_000);
                await assets.authorize(principal); // TODO@P3: needed?
                await assets.grant_permission({to_principal = principal; permission});
            };
        };
    };

    // TODO@P3: Should be in th frontend.
    public composite query({caller}) func userAccountBlob(): async Blob {
        Principal.toLedgerAccount(Principal.fromActor(this), ?(Principal.toBlob(caller)));
    };

}