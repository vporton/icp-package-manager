import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import ICPLedger "canister:nns-ledger";

persistent actor class Wallet({
    user: Principal; // Pass the anonymous principal `2vxsx-fae` to be controlled by nobody.
}) {
    let owner = user;

    private func onlyOwner(caller: Principal, msg: Text) {
        if (not Principal.isAnonymous(owner) and caller != owner) {
            Debug.trap(msg # ": no owner set");
        };
    };

    type Token = {
        symbol: Text;
        name: Text;
        canisterId: Principal;
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
            }
        ]
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
                        var amountAddCheckbox = ?10.0;
                        var amountAddInput = ?30.0;
                        var tokens = Array.append(defaultTokens(), [token]);
                    });
            };
        };
    };
};