/// Canister that takes on itself potentially non-returning calls.
import Copier "../copy_assets";
import Asset "mo:assets-api";

shared({caller = initialOwner}) actor class Copier() {
    var owner = initialOwner;

    /// We check owner, for only owner to be able to control Asset canisters
    private func onlyOwner(caller: Principal) {
        if (caller != owner) {
            Debug.trap("only owner");
        };
    };

    public shared({caller}) func changeOwner(newOwner: Principal) {
        onlyOwner(caller);

        owner := newOwner;
    };

    public shared({caller}) func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}) {
        onlyOwner(caller);

        Copier.copyAll({from; to});
    }
}