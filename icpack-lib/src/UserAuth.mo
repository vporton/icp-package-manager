import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import ECDSA "mo:ecdsa";
import PublicKey "mo:ecdsa/PublicKey";
import Signature "mo:ecdsa/Signature";

module {
    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Verify that the signature was produced by the private key corresponding to `pubKey`.
    /// Traps on malformed key or signature.
    public func verifySignature(pubKey: PubKey, user: Principal, signature: Blob): Bool {
        let publicKey = switch (PublicKey.fromBytes(Blob.toArray(pubKey).vals(), #spki)) {
            case (#ok k) k;
            case (#err e) {
                Debug.trap("pubkey error: " # e);
            };
        };
        let sig = switch (Signature.fromBytes(Blob.toArray(signature).vals(), ECDSA.Curve(#prime256v1), #raw)) {
            case (#ok s) s;
            case (#err e) {
                Debug.trap("signature error: " # e);
            };
        };
        publicKey.verify(Blob.toArray(Principal.toBlob(user)).vals(), sig);
    };

    public func checkOwnerSignature(packageManager: Principal, installationId: Nat, newOwner: Principal, signature: Blob): async* () {
        let backendActor = actor(Principal.toText(packageManager)): actor {
            getInstallationPubKey: query (id: Nat) -> async ?Blob;
        };
        let ?pubKey = await backendActor.getInstallationPubKey(installationId) else {
            Debug.trap("no public key");
        };
        if (not verifySignature(pubKey, newOwner, signature)) {
            Debug.trap("invalid signature");
        };
    };
}
