import Common "../src/common";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import {test} "mo:test";

/// Principals used for testing:
let princ = [
    Principal.fromText("aovwi-4maaa-aaaaa-qaagq-cai"),
    Principal.fromText("asrmz-lmaaa-aaaaa-qaaeq-cai"),
    Principal.fromText("by6od-j4aaa-aaaaa-qaadq-cai"),
    Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"),
    Principal.fromText("b77ix-eeaaa-aaaaa-qaada-cai"),
];

let test1 = {
    arg = HashMap.fromIter<Text, Common.InstalledModule>([
        ("a", #defaultInstalled(princ[0])),
        ("b", #additional(Buffer.fromArray<Principal>([princ[1], princ[2]]))),
        ("c", #defaultInstalled(princ[3])),
    ].vals(), 3, Text.equal, Text.hash);
    result = [("a", princ[0]), ("b", princ[1]), ("b", princ[2]), ("c", princ[3])];
};

let test2 = {
    arg = HashMap.fromIter<Text, Common.InstalledModule>([
        ("a", #additional(Buffer.fromArray<Principal>([princ[0], princ[1]]))),
        ("b", #defaultInstalled(princ[2])),
        ("c", #additional(Buffer.fromArray<Principal>([princ[3], princ[4]]))),
    ].vals(), 3, Text.equal, Text.hash);
    result = [("a", princ[0]), ("a", princ[1]), ("b", princ[2]), ("c", princ[3]), ("c", princ[4])];
};

let test3 = {
    arg = HashMap.fromIter<Text, Common.InstalledModule>([
        ("a", #defaultInstalled(princ[0])),
        ("b", #defaultInstalled(princ[1])),
    ].vals(), 3, Text.equal, Text.hash);
    result = [("a", princ[0]), ("b", princ[1])];
};

let test4 = {
    arg = HashMap.fromIter<Text, Common.InstalledModule>([
        ("a", #additional(Buffer.fromArray<Principal>([princ[0], princ[1]]))),
        ("b", #additional(Buffer.fromArray<Principal>([princ[2], princ[3]]))),
    ].vals(), 3, Text.equal, Text.hash);
    result = [("a", princ[0]), ("a", princ[1]), ("b", princ[2]), ("b", princ[3])];
};

let testsData = [test1, test2, test3, test4];

func pairCompare(a: (Text, Principal), b: (Text, Principal)): {#less; #equal; #greater} {
    switch (Text.compare(a.0, b.0)) {
        case (#less) #less;
        case (#equal) Principal.compare(a.1, b.1);
        case (#greater) #greater;
    };
};

var i = 0;
for (t in testsData.vals()) {
    test("test" # debug_show(i), func() {
        let iter = Common.ModulesIterator(t.arg);
        let res0 = Iter.sort<(Text, Principal)>(iter, pairCompare);
        let res = Iter.toArray<(Text, Principal)>(res0);
        let expected0 = Iter.toArray<(Text, Principal)>(t.result.vals());
        let expected = Array.sort<(Text, Principal)>(expected0, pairCompare);
        assert res == expected;
    });
    i += 1;
};
