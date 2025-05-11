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
import Battery "../package_manager_backend/battery";
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
import Array "mo:base/Array";
import IC "mo:base/ExperimentalInternetComputer";
import env "mo:env";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import CyclesLedger "canister:nns-ledger";
import CMC "canister:nns-cycles-minting";
import Data "canister:bootstrapper_data";
import Repository "canister:repository";
import Bookmarks "canister:bookmark";

actor class Bootstrapper() = this {
    /// `cyclesAmount` is the total cycles amount, including canister creation fee.
    transient let newCanisterCycles = 2_000_000_000_000; // TODO@P3: Make it editable (move to `bootstrapper_data`).

    transient let revenueRecipient = Principal.fromText(env.revenueRecipient);

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

        // ignore Cycles.accept<system>(); // TODO@P3
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            Debug.trap("icpack isn't a real package");
        };
        let modulesToInstall = HashMap.fromIter<Text, Common.SharedModule>(
            icPackPkgReal.modules.vals(), icPackPkgReal.modules.size(), Text.equal, Text.hash
        );

        let installedModules = HashMap.HashMap<Text, Principal>(modulesToInstall.size(), Text.equal, Text.hash);
        for (moduleName in modulesToInstall.keys()) {
            let cyclesAmount = if (moduleName == "battery") { // TODO@P3: Use only `newCanisterCycles`, copy to the battery later.
                3_000_000_000_000 // TODO@P3: It can be reduced to 2_000_000_000_000 for UI, but auto-test requires more.
            } else {
                newCanisterCycles;
            };
            // ignore Cycles.accept<system>(cyclesAmount);
            let {canister_id} = await* Install.myCreateCanister({
                controllers = ?[Principal.fromActor(this)]; // `null` does not work at least on localhost.
                cycles = cyclesAmount;
                subnet_selection = ?(
                    #Filter({subnet_type = if (env.isLocal) { null } else {?"Application"}})
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
        // TODO@P3: How many cycles?
        await (with cycles = 100_000_000_000) ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
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

        await Data.putFrontendTweaker(frontendTweakPubKey, {
            frontend;
            user;
        });

        // TODO@P3: Make adding a bookmark optional. (Or else, remove frontend bookmarking code.)
        //          For this, make the private key a part of the persistent link arguments?
        //          Need to ensure that the link is paid for (prevent DoS attacks).
        //          Another (easy) way is to add "Bookmark" checkbox to bootstrap.
        //          It seems that there is an easy solution: Leave a part of the paid sum on the account to pay for bookmark.
        ignore await Bookmarks.addBookmark({b = {frontend; backend}; battery; user});

        {installedModules = Iter.toArray(installedModules.entries())};
    };

    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    ///
    /// In testing mode, cycles are supplied as the main account of the bootstrapper canister
    /// and returned back to the same account.
    public shared({caller = user}) func bootstrapFrontend({
        frontendTweakPubKey: PubKey;
    }): async {installedModules: [(Text, Principal)]; spentCycles: Nat} {
        let amountToMove = convertICPToCycles(user).balance;
        if (amountToMove < ((13_000_000_000_000 - Common.cycles_transfer_fee): Nat)) {
            Debug.trap("You are required to put at least 13T cycles. Unspent cycles will be put onto your installed canisters and you will be able to claim them back.");
        };

        // TODO@P3: `- 5*Common.cycles_transfer_fee` and likewise seems to have superfluous multipliers.

        let {installedModules} = await doBootstrapFrontend(frontendTweakPubKey, user, amountToMove);

        let cyclesToBattery = if (env.isLocal) {
            (Cycles.balance() - 1_000_000_000_000): Nat; // Use the no-subaccount balance in test mode.
        } else {
            await CyclesLedger.icrc1_balance_of({
                owner = Principal.fromActor(this); subaccount = ?(Common.principalToSubaccount(user));
            });
        };

        {installedModules; spentCycles = amountToMove - cyclesToBattery};
    };

    /// Installs the backend after frontend is already installed, tweaks frontend.
    ///
    /// We don't allow to substitute user-chosen modules for the package manager itself,
    /// because it would be a security risk of draining cycles.
    public shared func bootstrapBackend({
        frontendTweakPrivKey: PrivKey; // TODO@P3: Rename.
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabulities, used only to add as a controller.
    }): async {spentCycles: Nat} {
        let pubKey = Sha256.fromBlob(#sha256, frontendTweakPrivKey);

        let tweaker = await Data.getFrontendTweaker(pubKey);

        let amountToMove = if (env.isLocal) {
            Cycles.balance();
        } else {
            await CyclesLedger.icrc1_balance_of({
                owner = Principal.fromActor(this); subaccount = ?(Common.principalToSubaccount(tweaker.user));
            });
        };

        // Move user's fund into current use:
        if (not env.isLocal) { // If isLocal, funds are already here.
            switch(await CyclesLedger.icrc1_transfer({
                to = {owner = Principal.fromActor(this); subaccount = null};
                fee = null;
                memo = null;
                from_subaccount = ?(Common.principalToSubaccount(tweaker.user));
                created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
                amount = amountToMove - 2*Common.cycles_transfer_fee;
            })) {
                case (#Err e) {
                    Debug.trap("transfer failed: " # debug_show(e));
                };
                case (#Ok _) {};
            };
        };

        // We can't `try` on this, because if it fails, we don't know the battery.
        // TODO@P3: `try` to return money back to user account.
        let {battery} = await doBootstrapBackend({
            pubKey;
            installedModules;
            user;
            amountToMove;
            tweaker
        });


        let lastBalance = if (env.isLocal) {
            Cycles.balance(); // Use the no-subaccount balance in test mode, deposit much (1000T) for testing.
        } else {
            await CyclesLedger.icrc1_balance_of({
                owner = Principal.fromActor(this); subaccount = ?(Common.principalToSubaccount(user));
            });
        };
        let cyclesToBattery = if (env.isLocal) {
            1_000_000_000_000_000; // Use the no-subaccount balance in test mode, deposit much (1000T) for testing.
        } else {
            lastBalance;
        };
        await (with cycles = cyclesToBattery - Common.cycles_transfer_fee) ic.deposit_cycles({canister_id = battery});

        {spentCycles = amountToMove - lastBalance};
    };

    public shared({caller}) func doBootstrapBackend({
        pubKey: PubKey;
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabulities, used only to add as a controller.
        amountToMove: Nat;
        tweaker: Data.FrontendTweaker;
    }): async {battery: Principal} {
        checkItself(caller);

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

        let controllers = [simpleIndirect, mainIndirect, backend, battery, user, Principal.fromActor(this)]; // TODO@P3: duplicate code
        let controllers2 = [simpleIndirect, mainIndirect, backend, battery, user]; // TODO@P3: duplicate code

        // TODO@P3: It may happen when the app is not installed because of an error.
        // the last stage of installation, not to add failed bookmark:
        await* tweakFrontend(tweaker, controllers2, user);
        await Data.deleteFrontendTweaker(pubKey);

        for (canister_id in installedModules2.vals()) { // including frontend
            // TODO@P3: We can provide these setting initially and thus update just one canister.
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

        label install for ((moduleName, canister_id) in installedModules.vals()) {
            if (moduleName == "frontend") {
                continue install;
            };
            let ?m = modulesToInstall.get(moduleName) else {
                Debug.trap("module not found");
            };
            Cycles.add<system>(1_000_000_000_000); // TODO@P3
            await* Install.myInstallCode({
                installationId = 0;
                upgradeId = null;
                canister_id;
                wasmModule = Common.unshareModule(m);
                arg = to_candid({});
                packageManager = if (moduleName == "backend") {
                    Principal.fromActor(this) // to call `facilitateBootstrap` below
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
            });
        };

        let backendActor = actor(Principal.toText(backend)): actor {
            facilitateBootstrap: shared ({
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryRO; 
                arg: Blob;
                initArg: ?Blob;
                user: Principal;
                mainIndirect: Principal;
                /// Additional packages to install after bootstrapping.
                preinstalledModules: [(Text, Principal)];
            }) -> async {minInstallationId: Common.InstallationId};
        };
        ignore await (with cycles = newCanisterCycles * Array.size(installedModules)) backendActor.facilitateBootstrap({
          packageName = "icpack";
          version = "stable";
          preinstalledModules = Iter.toArray(installedModules.vals()); // TODO@P3: No need in `.toArray()`.
          repo = Repository;
          arg = "";
          initArg = null;
          user;
          mainIndirect;
        });

        for (canister_id in installedModules2.vals()) { // including frontend
            // TODO@P3: We can provide these setting initially and thus update just one canister.
            await ic.update_settings({
                canister_id;
                sender_canister_version = null;
                settings = { // TODO@P3
                    compute_allocation = null;
                    // `indirect_canister_id` here is only for the package manager package:
                    controllers = ?controllers2;
                    freezing_threshold = null;
                    log_visibility = null;
                    memory_allocation = null;
                    reserved_cycles_limit = null;
                    wasm_memory_limit = null;
                };
            });
        };

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
        let owners = await assets.list_authorized();
        for (permission in [#Commit, #Prepare, #ManagePermissions].vals()) { // `#ManagePermissions` the last in the list not to revoke early
            for (owner in owners.vals()) {
                await assets.revoke_permission({
                    of_principal = owner; // TODO@P3: Why isn't it enough to remove `Principal.fromActor(this)`?
                    permission;
                });
            };
            for (principal in Iter.concat(controllers.vals(), [user].vals())) {
                await assets.authorize(principal); // TODO@P3: needed?
                await assets.grant_permission({to_principal = principal; permission});
            };
        };
    };

    // TODO@P3: Should be in th frontend.
    public composite query({caller}) func userAccountText(): async Text {
        let owner = Principal.fromActor(this);
        // let subaccount = if (env.isLocal) { null } else { ?(Principal.toBlob(caller)) };
        let subaccount = ?(AccountID.principalToSubaccount(caller));

        Account.toText({owner; subaccount});
    };

    private func convertICPToCycles(user: Principal): {balance: Nat} {
        let balance = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(Common.principalToSubaccount(user));
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(amountToMove) * (1.0 - env.revenueShare)));
        switch(await CyclesLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Common.principalToSubaccount(user));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - 2*Common.cycles_transfer_fee;
        })) {
            case (#Err e) {
                Debug.trap("transfer failed: " # debug_show(e));
            };
            case (#Ok _) {};
        };

        let subaccountArrayPart = Blob.toArray(Principal.toBlob(user));
        let subaccountArray = Array.tabulate<Nat8>(32, func (i) {
            if (i == 0) {
                Nat8.fromNat(Array.size(subaccountArrayPart));
            } else if (i-1 < Array.size(subaccountArrayPart)) {
                subaccountArrayPart[i];
            } else {
                0;
            };
        });
        let res = await CyclesLedger.icrc1_transfer({
            to = {owner = Principal.fromActor(CMC); subaccount = ?Blob.fromArray(subaccountArray)};
            fee = null;
            memo = ?"\4d\49\4e\54\00\00\00\00";
            from_subaccount = ?(Common.principalToSubaccount(user));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = balance - revenue - 2*Common.cycles_transfer_fee;
        });
        let #Ok tx = res else {
            Debug.trap("transfer failed: " # debug_show(res));
        };
        ignore await CMC.notify_top_up({
            block_index = Nat64.fromNat(tx);
            canister_id = Principal.fromActor(this);
        });
        {balance};
    };

    public query func balance(): async Nat {
        // TODO@P3: Allow only to the owner?
        Cycles.balance();
    };
}