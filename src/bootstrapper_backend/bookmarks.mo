import Principal "mo:base/Principal";
import Array "mo:base/Array";
import BTree "mo:stableheapbtreemap/BTree";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import env "mo:env";
import CyclesLedger "canister:cycles_ledger";

// TODO: Allow only the user to see his bookmarks?
persistent actor class Bookmarks({
    bootstrapper: Principal;
}) {
    let revenueRecipient = Principal.fromText(env.revenueRecipient);

    public type Bookmark = {
        frontend: Principal;
        backend: Principal;
    };

    private func bookmarksCompare(a: Bookmark, b: Bookmark): {#less; #equal; #greater} {
        switch (Principal.compare(a.frontend, b.frontend)) {
            case (#less) #less;
            case (#equal) Principal.compare(a.backend, b.backend);
            case (#greater) #greater;
        };
    };

    // private func bookmarkHash(a: Bookmark): Hash.Hash {
    //     Principal.hash(a.frontend) ^ Principal.hash(a.backend);
    // };

    /// user -> [Bookmark]
    stable let userToBookmark = BTree.init<Principal, [Bookmark]>(null);

    stable let bookmarks = BTree.init<Bookmark, ()>(null);

    public query({caller}) func getUserBookmarks(): async [Bookmark] {
        switch (BTree.get(userToBookmark, Principal.compare, caller)) {
            case (?a) a;
            case null [];
        };
    };

    public query func hasBookmark(b: Bookmark): async Bool {
        BTree.has(bookmarks, bookmarksCompare, b);
    };

    /// Returns whether bookmark already existed.
    public shared({caller}) func addBookmark({b: Bookmark; battery: Principal; user: Principal}): async Bool {
        if (caller != bootstrapper) {
            Debug.trap("bookmarks: not the owner");
        };

        let res = await CyclesLedger.icrc2_transfer_from({
            spender_subaccount = null;
            from = { owner = battery; subaccount = null };
            to = {owner = revenueRecipient; subaccount = null};
            fee = null;
            memo = null;
            created_at_time = ?(Nat64.fromNat(Int.abs(Time.now())));
            amount = env.bookmarkCost - 100_000_000; // minus transfer fee
        });
        switch (res) {
            case (#Err e) {
                Debug.print("Error transferring funds: " # debug_show(e));
                return false;
            };
            case (#Ok _) {};
        };
        switch (BTree.get(bookmarks, bookmarksCompare, b)) {
            case (?_) true;
            case null {
                ignore BTree.insert(bookmarks, bookmarksCompare, b, ());
                let a = BTree.get(userToBookmark, Principal.compare, user);
                let a2 = switch (a) {
                    case (?a) Array.append(a, [b]);
                    case null [b];
                };
                ignore BTree.insert(userToBookmark, Principal.compare, user, a2);
                false;
            };
        };
    };

    // TODO: inspect messages for max. principal length to be 29
}