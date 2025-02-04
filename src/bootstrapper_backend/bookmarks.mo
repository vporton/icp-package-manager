import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import TrieMap "mo:base/TrieMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Option "mo:base/Option";

// TODO: Allow only the user to see his bookmarks?
actor Bookmarks {
    public type Bookmark = {
        frontend: Principal;
        backend: Principal;
    };

    private func bookmarksEqual(a: Bookmark, b: Bookmark): Bool {
        a == b;
    };

    private func bookmarkHash(a: Bookmark): Hash.Hash {
        Principal.hash(a.frontend) ^ Principal.hash(a.backend);
    };

    /// user -> ((frontend, backend) -> ()))
    /// FIXME: persistent
    let userToBookmark = TrieMap.TrieMap<Principal, HashMap.HashMap<Bookmark, ()>>(Principal.equal, Principal.hash);

    /// FIXME: persistent
    /// TODO: Use https://mops.one/hash-map
    let bookmarks = TrieMap.TrieMap<Bookmark, ()>(bookmarksEqual, bookmarkHash);

    public query({caller}) func getUserBookmarks(): async [Bookmark] {
        switch (userToBookmark.get(caller)) {
            case (?a) Iter.toArray(Iter.map(
                a.entries(),
                func ((b, _): (Bookmark, ())): Bookmark = b,
            ));
            case null [];
        };
    };

    public query func hasBookmark(b: Bookmark): async Bool {
        Option.isSome(bookmarks.get(b));
    };

    /// Returns whether bookmark already existed.
    public shared({caller}) func addBookmark(b: Bookmark): async Bool {
        let result = Option.isSome(bookmarks.get(b));
        if (not result) {
            bookmarks.put(b, ());
        };
        switch (userToBookmark.get(caller)) {
            case (?subMap) {
                subMap.put(b, ());
            };
            case null {
                let subMap = HashMap.HashMap<Bookmark, ()>(1, bookmarksEqual, bookmarkHash);
                subMap.put(b, ());
                userToBookmark.put(caller, subMap);
            };
        };
        result;
    };

    // TODO: Charge the allocated by dev to limit DoS spam.
    // TODO: inspect messages for max. principal length to be 29
}