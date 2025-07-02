import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";
import Nat32 "mo:base/Nat32";
import Common "../common";
import Account "../lib/Account";
import AccountID "mo:account-identifier";
import ICRC1 "mo:icrc1-types";
import CyclesLedger "canister:cycles_ledger";
import ICPLedger "canister:nns-ledger";
import XR "canister:exchange-rate";
import Int "mo:base/Int";
import BootstrapperData "../bootstrapper_backend/BootstrapperData";
import UserAuth "../lib/UserAuth";

persistent actor class Wallet({
    installationId: Nat;
    user: Principal; // Pass the anonymous principal `2vxsx-fae` to be controlled by nobody.
    packageManager: Principal;
}) = this {
    stable var owner = user;

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

    transient var principalMap = Map.Make<Principal>(Principal.compare);
    stable var userData = principalMap.empty<UserData>();

    // Initialize default tokens for new users
    private func defaultTokens() : [Token] {
        [
            {
                symbol = "ICP";
                name = "Internet Computer";
                canisterId = Principal.fromActor(ICPLedger);
                archiveCanisterId = null; // FIXME@P2
            },
        ]
    };

    // FIXME@P1: Take stored pubKey instead of passing it here.
    /// Change wallet owner after verifying caller's signature with the provided public key.
    public shared({caller}) func setOwner(signature: Blob): async () {
        let backendActor = actor(Principal.toText(packageManager)): actor {
            getInstallationPubKey: query (id: Common.InstallationId) -> async ?Blob;
        };
        let ?pubKey = await backendActor.getInstallationPubKey(installationId) else {
            Debug.trap("no public key");
        };
        if (not UserAuth.verifySignature(pubKey, caller, signature)) {
            Debug.trap("invalid signature");
        };
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
                {amountAddCheckbox = ?10.0; amountAddInput = ?30.0};
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
                userData := principalMap.put<UserData>(
                    userData,
                    caller,
                    {
                        var amountAddCheckbox = ?10.0;
                        var amountAddInput = ?30.0;
                        var tokens = defaultTokens();
                    });
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

    // FIXME@P2: Disallow adding the same token twice.
    public shared({caller}) func addToken(token: Token): async () {
        onlyOwner(caller, "addToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.append(data.tokens, [token]);
            };
            case null {
                userData := principalMap.put<UserData>(
                    userData,
                    caller,
                    {
                        var amountAddCheckbox = ?10.0; // FIXME@P2: duplicate data
                        var amountAddInput = ?30.0;
                        var tokens = Array.append(defaultTokens(), [token]);
                    });
            };
        };
    };

    // TODO@P1: Filter by principal, not symbol.
    public shared({caller}) func removeToken(symbol: Text): async () {
        onlyOwner(caller, "removeToken");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.filter(data.tokens, func(t: Token): Bool {
                    t.symbol != symbol
                });
            };
            case null { /* Do nothing */ };
        };
    };

    public shared({caller}) func addArchiveCanister(symbol: Text, archiveCanisterId: Principal): async () {
        onlyOwner(caller, "addArchiveCanister");
        
        let data = principalMap.get(userData, caller);
        switch (data) {
            case (?data) {
                data.tokens := Array.map(data.tokens, func(t: Token): Token {
                    if (t.symbol == symbol) {
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

    // TODO@P3: duplicate code
    public query func getUserWallet(user: Principal): async {owner: Principal; subaccount: ?Blob} {
        // onlyOwner(caller, "getUserWallet");

        let canister = Principal.fromActor(this);
        {owner = canister; subaccount =
            if (Principal.isAnonymous(owner)) {
                ?(AccountID.principalToSubaccount(user));
            } else {
                null;
            }
        };
    };

    public query func getUserWalletText(user: Principal): async Text {
        // onlyOwner(caller, "getUserWallet");

        let canister = Principal.fromActor(this);
        if (Principal.isAnonymous(owner)) {
            let subaccount = ?(AccountID.principalToSubaccount(user));
            Account.toText({owner = canister; subaccount});
        } else {
            Principal.toText(canister);
        }
    };


    // query func isPersonalWallet(): async Bool {
    //     not owner.isAnonymous();
    // };

    public shared({caller}) func do_icrc1_transfer(token: ICRC1.Service, args: ICRC1.TransferArgs): async () {
        onlyOwner(caller, "do_icrc1_transfer");

        // `ignore` to avoid non-returning-function DoS attack
        ignore token.icrc1_transfer(
            if (Principal.isAnonymous(owner)) {
                {args with from_subaccount = ?(AccountID.principalToSubaccount(caller))};
            } else {
                args;
            },
        ); // `ignore` to avoid non-returning-function DoS attack
    };

    public shared({caller}) func do_secure_icrc1_transfer(token: ICRC1.Service, args: ICRC1.TransferArgs): async ICRC1.TransferResult {
        onlyOwner(caller, "do_secure_icrc1_transfer");
        if (Principal.fromActor(token) != Principal.fromActor(ICPLedger) and Principal.fromActor(token) != Principal.fromActor(CyclesLedger)) {
            Debug.trap("only certain tokens considered secure");
        };

        await token.icrc1_transfer(
            if (Principal.isAnonymous(owner)) {
                {args with from_subaccount = ?(AccountID.principalToSubaccount(caller))};
            } else {
                args;
            },
        );
    };

    public shared({caller}) func get_exchange_rate(symbol: Text): async {#Ok: Float; #Err} {
        if (Principal.isAnonymous(owner) or caller != owner) { // work only for personal wallet
            Debug.trap("get_exchange_rate: no owner set");
        };
        let res = await (with cycles = 1_000_000_000) XR.get_exchange_rate({
            base_asset = { symbol = "ICP"; class_ = #Cryptocurrency };
            quote_asset = { symbol = "XDR"; class_ = #FiatCurrency };
            timestamp = null;
        });
        switch (res) {
            case (#Ok rate) {
                #Ok (Float.fromInt64(Int64.fromNat64(rate.rate)) / Float.fromInt(10**Nat32.toNat(rate.metadata.decimals)));
            };
            case (#Err _) #Err;
        };
    };
};
