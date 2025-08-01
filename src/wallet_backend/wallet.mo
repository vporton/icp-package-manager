import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Time "mo:base/Time";
import Common "../common";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import ICRC1 "mo:icrc1-types";
import CyclesLedger "canister:cycles_ledger";
import ICPLedger "canister:nns-ledger";
import XR "canister:exchange-rate";
import Int "mo:base/Int";
import BootstrapperData "../bootstrapper_backend/BootstrapperData";
import UserAuth "mo:icpack-lib/UserAuth";
import Asset "mo:assets-api";

persistent actor class Wallet({
    installationId: Nat;
    packageManager: Principal;
}) = this {
    stable var owner = Principal.fromText("2vxsx-fae");

    private func onlyOwner(caller: Principal, msg: Text) {
        if (not Principal.isAnonymous(owner) and caller != owner) {
            Debug.trap(msg # ": no owner set");
        };
    };

    type Token = {
        symbol: Text;
        name: Text;
        canisterId: Principal;
        archiveCanisterId: ?Principal;
    };

    type UserData = {
        var amountAddCheckbox: ?Float;
        var amountAddInput: ?Float;
        var tokens: [Token];
    };

    private func initialUserData(): UserData {
        {
            var amountAddCheckbox = ?Common.default_amount_add_checkbox;
            var amountAddInput = ?Common.default_amount_add_input;
            var tokens = defaultTokens();
        }
    };

    transient var principalMap = Map.Make<Principal>(Principal.compare);
    stable var userData = principalMap.empty<UserData>();

    // Initialize default tokens for new users
    private func defaultTokens() : [Token] {
        [
            {
                symbol = "ICP";
                name = "Internet Computer";
                canisterId = Principal.fromActor(ICPLedger);
                archiveCanisterId = null; // TODO@P3: There are two ICP ledger archive canisters. They have canister IDs qsgjb-riaaa-aaaaa-aaaga-cai and qjdve-lqaaa-aaaaa-aaaeq-cai.
            },
        ]
    };

    /// Change wallet owner after verifying caller's signature with the provided public key.
    public shared({caller}) func setOwner(signature: Blob): async () {
        await* UserAuth.checkOwnerSignature(packageManager, installationId, caller, signature); // traps on error
        owner := caller;
    };

    public query({caller}) func getLimitAmounts(): async {amountAddCheckbox: ?Float; amountAddInput: ?Float} {
        onlyOwner(caller, "getLimitAmounts");

        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                {amountAddCheckbox = data.amountAddCheckbox; amountAddInput = data.amountAddInput};
            };
            case (_) {
                let initial = initialUserData(); // TODO@P3: inefficient
                {amountAddCheckbox = initial.amountAddCheckbox; amountAddInput = initial.amountAddInput};
            };
        };
    };

    public shared({caller}) func setLimitAmounts(values: {amountAddCheckbox: ?Float; amountAddInput: ?Float}): async () {
        onlyOwner(caller, "setLimitAmounts");

        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.amountAddCheckbox := values.amountAddCheckbox;
                data.amountAddInput := values.amountAddInput;
            };
            case null {
                userData := principalMap.put<UserData>(userData, caller, initialUserData());
            };
        };
    };

    public query({caller}) func getTokens(): async [Token] {
        onlyOwner(caller, "getTokens");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) { data.tokens };
            case null { defaultTokens() };
        };
    };

    public shared({caller}) func addToken(token: Token): async () {
        onlyOwner(caller, "addToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                for (t in data.tokens.vals()) {
                    if (t.canisterId == token.canisterId) {
                        Debug.trap("token already exists");
                    };
                };
                data.tokens := Array.append(data.tokens, [token]);
            };
            case null {
                userData := principalMap.put<UserData>(userData, caller, initialUserData());
            };
        };
    };

    public shared({caller}) func removeToken(canisterId: Principal): async () {
        onlyOwner(caller, "removeToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.filter(data.tokens, func(t: Token): Bool {
                    t.canisterId != canisterId
                });
            };
            case null { /* Do nothing */ };
        };
    };

    public shared({caller}) func addArchiveCanister(canisterId: Principal, archiveCanisterId: Principal): async () {
        onlyOwner(caller, "addArchiveCanister");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.map(data.tokens, func(t: Token): Token {
                    if (t.canisterId == canisterId) {
                        {t with archiveCanisterId = ?archiveCanisterId}
                    } else {
                        t
                    }
                });
            };
            case null { /* Do nothing */ };
        };
    };

    public query func isAnonymous(): async Bool {
        Principal.isAnonymous(owner);
    };

    public composite query func isAllInitialized(): async () {
        try {
            // Check that wallet backend is initialized (owner is set)
            if (Principal.isAnonymous(owner)) {
                Debug.trap("wallet_backend: not initialized (owner is anonymous)");
            };
            
            // Get the frontend canister principal from package manager
            let packageManagerActor: actor {
                getModulePrincipal: query (installationId: Nat, moduleName: Text) -> async Principal;
            } = actor(Principal.toText(packageManager));
            
            let frontendCanister = await packageManagerActor.getModulePrincipal(installationId, "frontend");
            
            // Check that frontend is accessible
            let frontend: Asset.AssetCanister = actor(Principal.toText(frontendCanister));
            let _ = await frontend.get({key = "/index.html"; accept_encodings = ["gzip"]});
        }
        catch(e) {
            Debug.print("Wallet isAllInitialized: " # Error.message(e));
            Debug.trap(Error.message(e));
        };
    };

    // query func isPersonalWallet(): async Bool {
    //     not owner.isAnonymous();
    // };


    // public shared({caller}) func get_exchange_rate(symbol: Text): async {#Ok: Float; #Err} {
    //     if (Principal.isAnonymous(owner) or caller != owner) { // work only for personal wallet
    //         Debug.trap("get_exchange_rate: no owner set");
    //     };
    //     let res = await (with cycles = 1_000_000_000) XR.get_exchange_rate({
    //         base_asset = { symbol = "USD"; class_ = #FiatCurrency };
    //         quote_asset = { symbol = symbol; class_ = #Cryptocurrency };
    //         // timestamp = ?Nat64.fromNat(Int.abs(Time.now() / 1_000_000_000 - 600));
    //         timestamp = null;
    //     });
    //     switch (res) {
    //         case (#Ok rate) {
    //             #Ok (Float.fromInt64(Int64.fromNat64(rate.rate)) / Float.fromInt(10**Nat32.toNat(rate.metadata.decimals)));
    //         };
    //         case (#Err e) {
    //             Debug.print(debug_show(e));
    //             #Err;
    //         };
    //     };
    // };
};
