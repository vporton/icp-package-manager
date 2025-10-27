import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Map "mo:core/Map";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Float "mo:core/Float";
import Int64 "mo:core/Int64";
import Nat64 "mo:core/Nat64";
import Nat32 "mo:core/Nat32";
import Time "mo:core/Time";
import Error "mo:core/Error";
import Common "../common";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import ICRC1 "mo:icrc1-types";
import CyclesLedger "canister:cycles_ledger";
import ICPLedger "canister:nns-ledger";
import XR "canister:exchange-rate";
import Int "mo:core/Int";
import BootstrapperData "../bootstrapper_backend/BootstrapperData";
import UserAuth "mo:icpack-lib/UserAuth";
import Asset "mo:assets-api";
import Result "mo:core/Result";

persistent actor class Wallet({
    installationId: Nat;
    packageManager: Principal;
}) = this {
    stable var owner = Principal.fromText("2vxsx-fae"); // Anonymous principal - will be replaced by actual user via setOwner method

    private func onlyOwner(caller: Principal, msg: Text): Result.Result<(), Text> {
        if (not Principal.isAnonymous(owner) and caller != owner) {
            return #err(msg # ": no owner set");
        };
        #ok;
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

    stable var userData = Map.empty<Principal, UserData>();

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
        switch (await* UserAuth.checkOwnerSignature(packageManager, installationId, caller, signature)) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };
        owner := caller;
    };

    public query({caller}) func getLimitAmounts(): async {amountAddCheckbox: ?Float; amountAddInput: ?Float} {
        switch (onlyOwner(caller, "getLimitAmounts")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };

        let data = Map.get(userData, Principal.compare, caller);
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
        switch (onlyOwner(caller, "setLimitAmounts")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };

        let data = Map.get(userData, Principal.compare, caller);
        switch (data) {
            case (?data) {
                data.amountAddCheckbox := values.amountAddCheckbox;
                data.amountAddInput := values.amountAddInput;
            };
            case null {
                ignore Map.insert(userData, Principal.compare, caller, initialUserData());
            };
        };
    };

    public query({caller}) func getTokens(): async [Token] {
        switch (onlyOwner(caller, "getTokens")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };
        
        let data = Map.get(userData, Principal.compare, caller);
        switch (data) {
            case (?data) { data.tokens };
            case null { defaultTokens() };
        };
    };

    public shared({caller}) func addToken(token: Token): async () {
        switch (onlyOwner(caller, "addToken")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };
        
        let data = Map.get(userData, Principal.compare, caller);
        switch (data) {
            case (?data) {
                for (t in data.tokens.vals()) {
                    if (t.canisterId == token.canisterId) {
                        throw Error.reject("token already exists");
                    };
                };
                data.tokens := Array.concat(data.tokens, [token]);
            };
            case null {
                ignore Map.insert(userData, Principal.compare, caller, initialUserData());
            };
        };
    };

    public shared({caller}) func removeToken(canisterId: Principal): async () {
        switch (onlyOwner(caller, "removeToken")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };
        
        let data = Map.get(userData, Principal.compare, caller);
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
                switch (onlyOwner(caller, "addArchiveCanister")) {
            case (#err(msg)) {
                throw Error.reject(msg);
            };
            case (#ok()) {};
        };
        
        let data = Map.get(userData, Principal.compare, caller);
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
            throw Error.reject(Error.message(e));
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
