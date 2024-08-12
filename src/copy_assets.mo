import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Asset "mo:assets-api";

module {
    public func copyAll({from: Asset.AssetCanister; to: Asset.AssetCanister}): async () {
        let fromAssets = await from.list({});
        let toAssets = await to.list({});
        let fromAssetsSet = HashMap.HashMap<Asset.Key, ()>(fromAssets.size(), Text.equal, Text.hash);
        for (key in Iter.map(fromAssets.vals(), func (x: {key: Asset.Key}): Asset.Key = x.key)) {
            fromAssetsSet.put(key, ());
        };
        let toAssetsSet = HashMap.HashMap<Text, ()>(toAssets.size(), Text.equal, Text.hash);
        for (key in Iter.map(toAssets.vals(), func (x: {key: Asset.Key}): Asset.Key = x.key)) {
            toAssetsSet.put(key, ());
        };
        let { batch_id } = await to.create_batch({});
        let buf = Buffer.Buffer<Asset.BatchOperationKind>(0);
        for (asset in toAssets.vals()) {
            if (fromAssetsSet.get(asset.key) == null) {
                buf.add(#DeleteAsset {key = asset.key});
            };
        };
        for (asset in fromAssets.vals()) {
            if (toAssetsSet.get(asset.key) == null) {
                let props = await to.get_asset_properties(asset.key);
                buf.add(#CreateAsset {
                    allow_raw_access = props.allow_raw_access;
                    content_type = asset.content_type;
                    enable_aliasing = props.is_aliased;
                    headers = props.headers;
                    key = asset.key;
                    max_age = props.max_age;
                });
            };
            // FIXME: Also remove missing encodings (not clear how to do this, except of using `to.get()`).
            for (encoding in asset.encodings.vals()) {
                let got = await from.get({key = asset.key; accept_encodings = [encoding.content_encoding]});
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
                        key = asset.key;
                        content_encoding = encoding.content_encoding;
                        index = i;
                        sha256 = null; // FIXME // sha256 of entire asset encoding, calculated by dfx and passed in SetAssetContentArguments
                    });
                    let chunk_info = await to.create_chunk({batch_id; content});
                    chunkIds.add(chunk_info.chunk_id);
                };
                buf.add(#SetAssetContent {
                    key = asset.key;
                    content_encoding = encoding.content_encoding;
                    chunk_ids = Buffer.toArray(chunkIds);
                    sha256 = null;
                });
            };
        };
        await to.commit_batch({batch_id; operations = Buffer.toArray(buf)});
    };
}