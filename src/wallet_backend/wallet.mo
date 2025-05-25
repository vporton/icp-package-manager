import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Map "mo:base/OrderedMap";

persistent actor class Wallet({
    user: Principal; // Pass the anonymous principal `2vxsx-fae` to be controlled by nobody.
}) {
    let owner = user;

    private func onlyOwner(caller: Principal, msg: Text) {
        if (not Principal.isAnonymous(owner) and caller != owner) {
            Debug.trap(msg # ": no owner set");
        };
    };

    type UserData = {
        var amountAddCheckbox: ?Float;
        var amountAddInput: ?Float;
    };

    transient var principalMap = Map.Make<Principal>(Principal.compare);
    stable var userData = principalMap.empty<UserData>();

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
                    {var amountAddCheckbox = ?10.0; var amountAddInput = ?30.0});
            };
        };
    };
};