import List "mo:core/List";
import Map "mo:core/Map";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Time "mo:core/Time";
import Asset "mo:assets-api";

module {
    public func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async* () {
        let fromAssets = await from.list({});
        let toAssets = await to.list({});
        let fromAssetsSet = Map.empty<Asset.Key, ()>(); // TODO@P3: Use `Set` instead of `Map`.
        for (x in fromAssets.vals()) {
            ignore Map.insert(fromAssetsSet, Text.compare, x.key, ());
        };
        let toAssetsSet = Map.empty<Text, {
            key: Asset.Key;
            content_type: Text;
            encodings: [{
                content_encoding: Text;
                sha256: ?Blob; // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
                length: Nat; // Size of this encoding's Blob. Calculated when uploading assets.
                modified: Time.Time;
            }];
        }>();
        for (x in toAssets.vals()) {
            ignore Map.insert(toAssetsSet, Text.compare, x.key, x);
        };
        let { batch_id } = await to.create_batch({});
        let buf = List.empty<Asset.BatchOperationKind>();
        for (toAsset in toAssets.vals()) {
            if (Map.get(fromAssetsSet, Text.compare, toAsset.key) == null) {
                List.add(buf, #DeleteAsset {key = toAsset.key});
            };
        };
        for (fromAsset in fromAssets.vals()) {
            let props = await from.get_asset_properties(fromAsset.key);
            switch (Map.get(toAssetsSet, Text.compare, fromAsset.key)) {
                case(?toAsset) {
                    // Remove missing encodings:
                    let fromEncodings = Map.empty<Asset.Key, ()>(); // TODO@P3: Use `Set` instead of `Map`.
                    for (fromEncoding in fromAsset.encodings.vals()) {
                        ignore Map.insert(fromEncodings, Text.compare, fromEncoding.content_encoding, ());
                    };
                    for (encoding in toAsset.encodings.vals()) {
                        if (Map.get(fromEncodings, Text.compare, encoding.content_encoding) == null) {
                            List.add(buf, #UnsetAssetContent {
                                key = fromAsset.key;
                                content_encoding = encoding.content_encoding;
                            })
                        };
                    };

                    List.add(buf, #SetAssetProperties {
                        key = fromAsset.key;
                        max_age = ?props.max_age;
                        headers = ?props.headers;
                        allow_raw_access = ?props.allow_raw_access;
                        is_aliased = ?props.is_aliased;
                    });
                };
                case null {
                    List.add(buf, #CreateAsset {
                        allow_raw_access = props.allow_raw_access;
                        content_type = fromAsset.content_type;
                        enable_aliasing = props.is_aliased;
                        headers = props.headers;
                        key = fromAsset.key;
                        max_age = props.max_age;
                    });
                };
            };

            for (encoding in fromAsset.encodings.vals()) {
                let got = await from.get({key = fromAsset.key; accept_encodings = [encoding.content_encoding]});
                let chunksNum = if (got.total_length == 0) {
                    0;
                } else {
                    Int.abs((got.total_length: Int - 1) / got.content.size() + 1);
                };
                let chunkIds = List.empty<Asset.ChunkId>();
                let chunk_info = await to.create_chunk({batch_id; content = got.content});
                List.add(chunkIds, chunk_info.chunk_id);
                for (i in Nat.range(1, chunksNum)) {
                    let { content } = await from.get_chunk({
                        key = fromAsset.key;
                        content_encoding = encoding.content_encoding;
                        index = i;
                        sha256 = encoding.sha256; // sha256 of entire fromAsset encoding, calculated by dfx and passed in SetAssetContentArguments
                    });
                    let chunk_info = await to.create_chunk({batch_id; content});
                    List.add(chunkIds, chunk_info.chunk_id);
                };
                List.add(buf, #SetAssetContent {
                    key = fromAsset.key;
                    content_encoding = encoding.content_encoding;
                    chunk_ids = List.toArray(chunkIds);
                    sha256 = null;
                });
            };
        };
        await to.commit_batch({batch_id; operations = List.toArray(buf)});
    };
}