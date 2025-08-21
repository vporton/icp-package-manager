import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Map "mo:core/Map";
import Set "mo:core/Set";
import Error "mo:core/Error";

// TODO@P3: Allow only the user to see his bookmarks?
persistent actor class Bookmarks(initialOwner: Principal) {
    public type Bookmark = {
        frontend: Principal;
        backend: Principal;
    };

    var bootstrapper: Principal = Principal.fromText("aaaaa-aa"); // TODO@P3: Rewrite DFX and make it class argument instead.

    var initialized: Bool = false;

    public shared({caller}) func init(args: {bootstrapper: Principal}): async () {
        if (caller != initialOwner) {
            throw Error.reject("bookmarks: not the initiaizer");
        };
        if (initialized) {
            throw Error.reject("bookmarks: already initialized");
        };
        bootstrapper := args.bootstrapper;
        initialized := true;
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
    /// FIXME@P1: Use `List` instead of array.
    stable var userToBookmark = Map.empty<Principal, [Bookmark]>();

    stable var bookmarks = Set.empty<Bookmark>();

    public query({caller}) func getUserBookmarks(): async [Bookmark] {
        switch (Map.get(userToBookmark, Principal.compare, caller)) {
            case (?a) a;
            case null [];
        };
    };

    public query func hasBookmark(b: Bookmark): async Bool {
        Set.contains<Bookmark>(bookmarks, bookmarksCompare, b);
    };

    // TODO@P3: Remove unused argument `battery`.
    /// Returns whether bookmark already existed.
    public shared({caller}) func addBookmark({b: Bookmark; battery = _: Principal; user: Principal}): async Bool {
        if (caller != bootstrapper) {
            throw Error.reject("bookmarks: not the owner");
        };

        // let res = await CyclesLedger.icrc2_transfer_from({
        //     spender_subaccount = null;
        //     from = { owner = battery; subaccount = null };
        //     to = {owner = revenueRecipient; subaccount = null};
        //     fee = null;
        //     memo = null;
        //     created_at_time = null; // ?(Nat64.fromNat(Int.abs(Time.now())));
        //     amount = env.bookmarkCost - 100_000_000; // minus transfer fee
        // });
        // switch (res) {
        //     case (#Err e) {
        //         Debug.print("Error transferring funds: " # debug_show(e));
        //         return false;
        //     };
        //     case (#Ok _) {};
        // };
        if (Set.contains<Bookmark>(bookmarks, bookmarksCompare, b)) {
            true;
        } else {
            ignore Set.insert<Bookmark>(bookmarks, bookmarksCompare, b);
            let a = Map.get(userToBookmark, Principal.compare, user);
            let a2 = switch (a) {
                case (?a) Array.concat(a, [b]);
                case null [b];
            };
            ignore Map.insert(userToBookmark, Principal.compare, user, a2);
            false;
        };
    };
}