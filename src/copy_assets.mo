import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Asset "mo:assets-api";

module {
    public func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async* () {
        let fromAssets = await from.list({});
        let toAssets = await to.list({});
        let fromAssetsSet = HashMap.HashMap<Asset.Key, ()>(fromAssets.size(), Text.equal, Text.hash);
        for (x in fromAssets.vals()) {
            fromAssetsSet.put(x.key, ());
        };
        let toAssetsSet = HashMap.HashMap<Text, {
            key: Asset.Key;
            content_type: Text;
            encodings: [{
                content_encoding: Text;
                sha256: ?Blob; // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
                length: Nat; // Size of this encoding's Blob. Calculated when uploading assets.
                modified: Time.Time;
            }];
        }>(toAssets.size(), Text.equal, Text.hash);
        for (x in toAssets.vals()) {
            toAssetsSet.put(x.key, x);
        };
        let { batch_id } = await to.create_batch({});
        let buf = Buffer.Buffer<Asset.BatchOperationKind>(0);
        for (toAsset in toAssets.vals()) {
            if (fromAssetsSet.get(toAsset.key) == null) {
                buf.add(#DeleteAsset {key = toAsset.key});
            };
        };
        for (fromAsset in fromAssets.vals()) {
            let props = await from.get_asset_properties(fromAsset.key);
            switch (toAssetsSet.get(fromAsset.key)) {
                case(?toAsset) {
                    // Remove missing encodings:
                    let fromEncodings = HashMap.HashMap<Asset.Key, ()>(0, Text.equal, Text.hash);
                    for (fromEncoding in fromAsset.encodings.vals()) {
                        fromEncodings.put(fromEncoding.content_encoding, ());
                    };
                    for (encoding in toAsset.encodings.vals()) {
                        if (fromEncodings.get(encoding.content_encoding) == null) {
                            buf.add(#UnsetAssetContent {
                                key = fromAsset.key;
                                content_encoding = encoding.content_encoding;
                            })
                        };
                    };

                    buf.add(#SetAssetProperties {
                        key = fromAsset.key;
                        max_age = ?props.max_age;
                        headers = ?props.headers;
                        allow_raw_access = ?props.allow_raw_access;
                        is_aliased = ?props.is_aliased;
                    });
                };
                case null {
                    buf.add(#CreateAsset {
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
                let chunkIds = Buffer.Buffer<Asset.ChunkId>(chunksNum);
                let chunk_info = await to.create_chunk({batch_id; content = got.content});
                chunkIds.add(chunk_info.chunk_id);
                for (i in Iter.range(1, chunksNum - 1)) {
                    let { content } = await from.get_chunk({
                        key = fromAsset.key;
                        content_encoding = encoding.content_encoding;
                        index = i;
                        sha256 = encoding.sha256; // sha256 of entire fromAsset encoding, calculated by dfx and passed in SetAssetContentArguments
                    });
                    let chunk_info = await to.create_chunk({batch_id; content});
                    chunkIds.add(chunk_info.chunk_id);
                };
                buf.add(#SetAssetContent {
                    key = fromAsset.key;
                    content_encoding = encoding.content_encoding;
                    chunk_ids = Buffer.toArray(chunkIds);
                    sha256 = null;
                });
            };
        };
        await to.commit_batch({batch_id; operations = Buffer.toArray(buf)});
    };
}