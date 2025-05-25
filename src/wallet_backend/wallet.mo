import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

persistent actor class Wallet({
    user: Principal; // Pass the anonymous principal `2vxsx-fae` to be controlled by nobody.
}) {
    let owner = user;

    private func onlyOwner(caller: Principal, msg: Text) {
        if (not Principal.isAnonymous(user) and caller != owner) {
            Debug.trap(msg # ": no owner set");
        };
    };

    var amountAddCheckbox = ?10.0;
    var amountAddInput = ?30.0;

    public query({caller}) func getLimitAmounts(): async {amountAddCheckbox: ?Float; amountAddInput: ?Float} {
        onlyOwner(caller, "getLimitAmounts");

        {amountAddCheckbox; amountAddInput};
    };

    public shared({caller}) func setLimitAmounts(values: {amountAddCheckbox: ?Float; amountAddInput: ?Float}): async () {
        onlyOwner(caller, "setLimitAmounts");

        amountAddCheckbox := values.amountAddCheckbox;
        amountAddInput := values.amountAddInput;
    };
};