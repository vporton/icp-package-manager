import Principal "mo:core/Principal";
import Blob "mo:core/Blob";
import Error "mo:core/Error";
import Result "mo:core/Result";
import Debug "mo:core/Debug";
import ECDSA "mo:ecdsa";
import PublicKey "mo:ecdsa/PublicKey";
import Signature "mo:ecdsa/Signature";

module {
    public type PubKey = Blob;
    public type PrivKey = Blob;

    /// Verify that the signature was produced by the private key corresponding to `pubKey`.
    /// Traps on malformed key or signature.
    public func verifySignature(pubKey: PubKey, user: Principal, signature: Blob): Result.Result<Bool, Text> {
        let publicKey = switch (PublicKey.fromBytes(Blob.toArray(pubKey).vals(), #spki)) {
            case (#ok k) k;
            case (#err e) {
                return #err("pubkey error: " # e);
            };
        };
        let sig = switch (Signature.fromBytes(Blob.toArray(signature).vals(), ECDSA.Curve(#prime256v1), #raw)) {
            case (#ok s) s;
            case (#err e) {
                return #err("signature error: " # e);
            };
        };
        #ok(publicKey.verify(Blob.toArray(Principal.toBlob(user)).vals(), sig));
    };

    public func checkOwnerSignature(packageManager: Principal, installationId: Nat, newOwner: Principal, signature: Blob)
        : async* Result.Result<(), Text>
    {
        let backendActor = actor(Principal.toText(packageManager)): actor {
            getInstallationPubKey: query (id: Nat) -> async ?Blob;
        };
        let ?pubKey = await backendActor.getInstallationPubKey(installationId) else {
            return #err("no public key");
        };
        switch (verifySignature(pubKey, newOwner, signature)) {
            case (#err e) #err e;
            case (#ok false) #err("invalid signature");
            case (#ok true) #ok();
        };
    };
}
