import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

persistent actor class Wallet({
    initialOwner: ?Principal;
}) {
    let owner = initialOwner;

    private func onlyOwner(caller: Principal, msg: Text) {
        switch(owner) {
            case (?owner) {
                if (caller != owner) {
                    Debug.trap("Only the owner can call " # msg);
                };
            };
            case null {};
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