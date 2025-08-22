/// This module is legible to non-returning-function attack. Throw it away if it fails this way.
/// Data is stored in `bootstrapper_data` instead.
import Asset "mo:assets-api";
import Iter "mo:core/Iter";
import Text "mo:core/Text";
import Principal "mo:core/Principal";
import Map "mo:core/Map";
import Debug "mo:core/Debug";
import Sha256 "mo:sha2/Sha256";
import {ic} "mo:ic";
import Common "../common";
import Install "../install";
import Battery "../package_manager_backend/battery";
import Cycles "mo:core/Cycles";
import Nat64 "mo:core/Nat64";
import Int "mo:core/Int";
import Time "mo:core/Time";
import Float "mo:core/Float";
import Error "mo:core/Error";
import Nat "mo:core/Nat";
import List "mo:core/List";
import Blob "mo:core/Blob";
import Nat8 "mo:core/Nat8";
import Array "mo:core/Array";
import IC "mo:core/InternetComputer";
import Order "mo:core/Order";
import env "mo:env";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import UserAuth "mo:icpack-lib/UserAuth";
import BootstrapperData "canister:bootstrapper_data";
import ICPLedger "canister:nns-ledger";
import CyclesLedger "canister:cycles_ledger";
import CMC "canister:nns-cycles-minting";
import Data "canister:bootstrapper_data";
import Repository "canister:repository";
import Bookmarks "canister:bookmark";

persistent actor class Bootstrapper() = this {
    /// `cyclesAmount` is the total cycles amount, including canister creation fee.
    transient let newCanisterCycles = 2_000_000_000_000; // TODO@P3: Make it editable (move to `bootstrapper_data`).

    transient let revenueRecipient = Principal.fromText(env.revenueRecipient);

    /// TODO@P3: Do we need this check?
    private func checkItself(caller: Principal): async* () {
        if (caller != Principal.fromActor(this)) {
            throw Error.reject("can be called only by itself");
        };
    };

    public type PubKey = Blob; // TODO@P3: duplicate code here

    public shared({caller}) func doBootstrapFrontend(frontendTweakPubKey: PubKey, user: Principal, amountToMove: Nat)
        : async {installedModules: [(Text, Principal)]}
    {
        await* checkItself(caller);

        // ignore Cycles.accept<system>(); // TODO@P3
        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            throw Error.reject("icpack isn't a real package");
        };
        let modulesToInstall = Map.fromIter<Text, Common.SharedModule>(icPackPkgReal.modules.vals(), Text.compare);

        let installedModules = Map.empty<Text, Principal>();
        for (moduleName in Map.keys(modulesToInstall)) {
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
            ignore Map.insert(installedModules, Text.compare, moduleName, canister_id);
        };

        let ?frontend = Map.get(installedModules, Text.compare, "frontend") else {
            throw Error.reject("module not deployed");
        };
        let ?backend = Map.get(installedModules, Text.compare, "backend") else {
            throw Error.reject("module not deployed");
        };
        let ?simpleIndirect = Map.get(installedModules, Text.compare, "simple_indirect") else {
            throw Error.reject("module not deployed");
        };
        let ?mainIndirect = Map.get(installedModules, Text.compare, "main_indirect") else {
            throw Error.reject("module not deployed");
        };
        let ?battery = Map.get(installedModules, Text.compare, "battery") else {
            throw Error.reject("module not deployed");
        };

        let ?mFrontend = Map.get(modulesToInstall, Text.compare, "frontend") else {
            throw Error.reject("module not found");
        };
        let wasmModuleLocation = Common.extractModuleLocation(mFrontend.code);
        let wasm_module = await Repository.getWasmModule(wasmModuleLocation.1);
        // https://github.com/vporton/measure-install_code
        await (with cycles = 1059 * wasm_module.size()) ic.install_code({ // See also https://forum.dfinity.org/t/is-calling-install-code-with-untrusted-code-safe/35553
            arg = to_candid({});
            wasm_module;
            mode = #install;
            canister_id = frontend;
            sender_canister_version = null; // TODO@P3
        });
        await* Install.copyAssetsIfAny({
            wasmModule = Common.unshareModule(mFrontend);
            canister_id = frontend;
            simpleIndirect;
            mainIndirect;
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

        {installedModules = Iter.toArray(Map.entries(installedModules))};
    };

    /// We don't allow to substitute user-chosen modules, because it would be a security risk of draining cycles.
    ///
    /// In testing mode, cycles are supplied as the main account of the bootstrapper canister
    /// and returned back to the same account.
    public shared({caller = user}) func bootstrapFrontend({
        frontendTweakPubKey: PubKey;
    }): async {installedModules: [(Text, Principal)]; spentCycles: Int} {
        let initialBalance = Cycles.balance();
        let amountToMove = await Data.removeUserCycleBalance(user);

        if (amountToMove < ((Common.minimalFunding - Common.cycles_transfer_fee): Nat)) {
            throw Error.reject("You are required to put at least 13T cycles. Unspent cycles will be put onto your installed canisters and you will be able to claim them back.");
        };

        // TODO@P3: `- 5*Common.cycles_transfer_fee` and likewise seems to have superfluous multipliers.

        let {installedModules} = await /*(with cycles = amountToMove)*/ doBootstrapFrontend(frontendTweakPubKey, user, amountToMove);

        let ?battery = Iter.filter(installedModules.vals(), func (x: (Text, Principal)): Bool = x.0 == "battery").next() else {
            throw Error.reject("error getting battery");
        };
        let cyclesToBattery = amountToMove - env.bootstrapFrontendCost;
        await (with cycles = cyclesToBattery - Common.cycles_transfer_fee) ic.deposit_cycles({canister_id = battery.1});

        let spentCycles = (initialBalance: Int) - Cycles.balance() - cyclesToBattery;
        {installedModules; spentCycles};
    };

    /// Installs the backend after frontend is already installed, tweaks frontend.
    ///
    /// We don't allow to substitute user-chosen modules for the package manager itself,
    /// because it would be a security risk of draining cycles.
    public shared func bootstrapBackend({
        frontendTweakPubKey: PubKey; // TODO@P3: Rename.
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabilities, used only to add as a controller.
        signature: Blob;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async {spentCycles: Int} {
        let initialBalance = Cycles.balance();

        let tweaker = await Data.getFrontendTweaker(frontendTweakPubKey);
        switch (UserAuth.verifySignature(frontendTweakPubKey, user, signature)) {
            case (#err e) throw Error.reject(e);
            case (#ok false) throw Error.reject("account validation failed");
            case (#ok true) {};
        };

        // let amountToMove = switch (principalMap.get(userCycleBalanceMap, user)) { // wrong user
        //     case (?amount) amount;
        //     case null 0;
        // };
        // userCycleBalanceMap := principalMap.put(userCycleBalanceMap, user, 0);
        let amountToMove = Common.minimalFunding - env.bootstrapFrontendCost;

        // Move user's fund into current use:
        // We can't `try` on this, because if it fails, we don't know the battery.
        // TODO@P3: `try` to return money back to user account.
        let {battery} = await doBootstrapBackend({
            pubKey = frontendTweakPubKey;
            installedModules;
            user;
            amountToMove;
            tweaker;
            additionalPackages;
        });

        let spentCycles = (initialBalance: Int) - Cycles.balance();
        {spentCycles};
    };

    public shared({caller}) func doBootstrapBackend({
        pubKey: PubKey;
        installedModules: [(Text, Principal)];
        user: Principal; // to address security vulnerabilities, used only to add as a controller.
        amountToMove: Nat;
        tweaker: Data.FrontendTweaker;
        additionalPackages: [{
            packageName: Common.PackageName;
            version: Common.Version;
            repo: Common.RepositoryRO;
        }];
    }): async {battery: Principal} {
        await* checkItself(caller);

        let icPackPkg = await Repository.getPackage("icpack", "stable");
        let #real icPackPkgReal = icPackPkg.specific else {
            throw Error.reject("icpack isn't a real package");
        };

        let modulesToInstall = Map.fromIter<Text, Common.SharedModule>(icPackPkgReal.modules.vals(), Text.compare);

        // We bootstrap backend at this stage:
        let installedModules2 = Map.fromIter<Text, Principal>(installedModules.vals(), Text.compare);
        let ?backend = Map.get(installedModules2, Text.compare, "backend") else {
            throw Error.reject("module not deployed");
        };
        let ?mainIndirect = Map.get(installedModules2, Text.compare, "main_indirect") else {
            throw Error.reject("module not deployed");
        };
        let ?simpleIndirect = Map.get(installedModules2, Text.compare, "simple_indirect") else {
            throw Error.reject("module not deployed");
        };
        let ?battery = Map.get(installedModules2, Text.compare, "battery") else {
            throw Error.reject("module not deployed");
        };

        let controllers = [simpleIndirect, mainIndirect, backend, battery, user, Principal.fromActor(this)]; // TODO@P3: duplicate code
        let controllers2 = [simpleIndirect, mainIndirect, backend, battery, user]; // TODO@P3: duplicate code

        // TODO@P3: It may happen when the app is not installed because of an error.
        // the last stage of installation, not to add failed bookmark:
        await* tweakFrontend(tweaker, controllers2, user);
        await Data.deleteFrontendTweaker(pubKey);

        for (canister_id in Map.values(installedModules2)) { // including frontend
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
            let ?m = Map.get(modulesToInstall, Text.compare, moduleName) else {
                throw Error.reject("module not found");
            };
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
            installPackages: shared ({
                packages: [{
                    packageName: Common.PackageName;
                    version: Common.Version;
                    repo: Common.RepositoryRO;
                    arg: Blob;
                    initArg: ?Blob;
                }];
                user: Principal;
                afterInstallCallback: ?{ canister: Principal; name: Text; data: Blob };
            }) -> async {minInstallationId: Common.InstallationId};
        };
        ignore await backendActor.facilitateBootstrap({
          packageName = "icpack";
          version = "stable";
          preinstalledModules = Iter.toArray(installedModules.vals()); // TODO@P3: No need in `.toArray()`.
          repo = Repository;
          arg = "";
          initArg = null;
          user;
          mainIndirect;
        });

        for (canister_id in Map.values(installedModules2)) { // including frontend
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

        ignore await backendActor.installPackages({
            packages = Iter.toArray(Iter.map<{
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryRO;
            }, {
                packageName: Common.PackageName;
                version: Common.Version;
                repo: Common.RepositoryRO;
                arg: Blob;
                initArg: ?Blob;
            }>(additionalPackages.vals(), func (p) = {
                packageName = p.packageName;
                version = p.version;
                repo = p.repo;
                arg = to_candid({});
                initArg = ?to_candid({});
            }));
            user;
            afterInstallCallback = null;
        });

        {battery};
    };


    /// Internal. Updates controllers and owners of the frontend.
    ///
    /// TODO@P3: Rename.
    private func tweakFrontend(
        tweaker: Data.FrontendTweaker,
        controllers: [Principal],
        user: Principal, // to address security vulnerabilities, used only to add a controller.
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
    // TODO@P3: duplicate code
    public composite query({caller}) func userAccountText(): async Text {
        let owner = Principal.fromActor(this);
        let subaccount = ?(AccountID.principalToSubaccount(caller));

        Account.toText({owner; subaccount});
    };

    public shared({caller = user}) func withdrawCycles(): async {balance: Nat} {
        let balance = await CyclesLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(Blob.toArray(Common.principalToSubaccount(user)));
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(balance) * env.revenueShare));
        let res2 = await CyclesLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Blob.toArray(Common.principalToSubaccount(user)));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.cycles_transfer_fee;
        });
        let #Ok tx = res2 else {
            throw Error.reject("transfer failed: " # debug_show(res2));
        };

        let res3 = await CyclesLedger.withdraw({
            amount = balance - revenue - Common.cycles_transfer_fee;
            from_subaccount = ?(Blob.toArray(Common.principalToSubaccount(user)));
            to = Principal.fromActor(this);
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
        });
        let #Ok tx3 = res3 else {
            throw Error.reject("transfer failed: " # debug_show(res3));
        };

        // Update user cycle balance in BootstrapperData
        await Data.addToUserCycleBalance(user, balance - revenue - Common.cycles_transfer_fee);
        {balance = balance - revenue - Common.cycles_transfer_fee};
    };

    public shared({caller = user}) func convertICPToCycles(): async {balance: Nat} {
        let icpBalance = await ICPLedger.icrc1_balance_of({
            owner = Principal.fromActor(this); subaccount = ?(Common.principalToSubaccount(user));
        });

        // Deduct revenue:
        let revenue = Int.abs(Float.toInt(Float.fromInt(icpBalance) * env.revenueShare));

        let res = await ICPLedger.icrc1_transfer({
            to = {
                owner = Principal.fromActor(CMC);
                subaccount = ?(Common.principalToSubaccount(Principal.fromActor(this)));
            };
            fee = null;
            memo = ?"TPUP\00\00\00\00";
            from_subaccount = ?(Common.principalToSubaccount(user));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = icpBalance - revenue - Common.icp_transfer_fee;
        });
        let #Ok tx = res else {
            throw Error.reject("transfer failed: " # debug_show(res));
        };
        let res2 = await ICPLedger.icrc1_transfer({
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            from_subaccount = ?(Common.principalToSubaccount(user));
            created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = revenue - Common.icp_transfer_fee;
        });
        let #Ok tx2 = res2 else {
            throw Error.reject("transfer failed: " # debug_show(res2));
        };
        let res3 = await CMC.notify_top_up({
            block_index = Nat64.fromNat(tx);
            canister_id = Principal.fromActor(this);
        });
        let #Ok cyclesAmount = res3 else {
            throw Error.reject("notify_top_up failed: " # debug_show(res2));
        };

        // Update user cycle balance in BootstrapperData
        await Data.addToUserCycleBalance(user, cyclesAmount);
        {balance = cyclesAmount};
    };

    public query func balance(): async Nat {
        // TODO@P3: Allow only to the owner?
        Cycles.balance();
    };

    public composite query({caller = user}) func userCycleBalance(): async Nat {
        // TODO@P3: Allow only to the owner?
        await Data.getUserCycleBalance(user);
    };
}