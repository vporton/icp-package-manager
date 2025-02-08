import Principal "mo:base/Principal";
import Array "mo:base/Array";
import BTree "mo:stableheapbtreemap/BTree";

// TODO: Allow only the user to see his bookmarks?
persistent actor Bookmarks {
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
    public shared({caller}) func addBookmark(b: Bookmark): async Bool {
        switch (BTree.get(bookmarks, bookmarksCompare, b)) {
            case (?_) true;
            case null {
                ignore BTree.insert(bookmarks, bookmarksCompare, b, ());
                let a = BTree.get(userToBookmark, Principal.compare, caller);
                let a2 = switch (a) {
                    case (?a) Array.append(a, [b]);
                    case null [b];
                };
                ignore BTree.insert(userToBookmark, Principal.compare, caller, a2);
                false;
            };
        };
    };

    // TODO: Charge the allocated by dev to limit DoS spam.
    // TODO: inspect messages for max. principal length to be 29
}