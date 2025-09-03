import Asset "mo:assets-api";
import Map "mo:core/Map";
import List "mo:core/List";
import Text "mo:core/Text";

persistent actor MultiAssets {
	type Key = Text;

	type Asset = {
		key: Key;
		content_type: Text;
        max_age : ?Nat64;
        headers : ?[Asset.HeaderField];
        enable_aliasing : ?Bool;
        allow_raw_access : ?Bool;
		content: [{
            content_encoding: Text;
            content: Blob;
            sha256: Blob;
        }];
	};

    let assets = Map.empty<Key, Asset>();

    public func store(asset: Asset): async () {
        ignore Map.insert<Key, Asset>(assets, Text.compare, asset.key, asset);
    };

    public func get(key: Key): async ?Asset {
        Map.get(assets, Text.compare, key);
    };

    public func listByPrefix(prefix: Key): async [Asset] {
        let result = List.empty<Asset>();    
        let iter = Map.entriesFrom(assets, Text.compare, prefix);
        label r loop {
            let v = iter.next();
            switch (v) {
                case (?(k, v)) {
                    if (Text.startsWith(k, #text prefix)) {
                        List.add(result, v);
                    } else {
                        break r;
                    };
                };
                case null {
                    break r;
                };
            };
        };
        List.toArray(result);
    };

    public func clearByPrefix(prefix: Key): async () {
        label r loop {
            let iter = Map.entriesFrom(assets, Text.compare, prefix);
            let v = iter.next();
            switch (v) {
                case (?(k, v)) {
                    if (not Text.startsWith(k, #text prefix)) {
                        break r;
                    };
                };
                case null {
                    break r;
                };
            };
        };
    };
}


