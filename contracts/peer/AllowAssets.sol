// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {ASSET, ASSET_KEY, BlockRef} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "peerAllowAssets";

abstract contract PeerAllowAssets is PeerBase {
    uint internal immutable peerAllowAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, ASSET, peerAllowAssetsId);
    }

    function peerAllowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerAllowAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint i = 0;
        while (i < request.length) {
            BlockRef memory ref = Blocks.from(request, i);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset(request);
            peerAllowAsset(asset, meta);
            i = ref.end;
        }
        return response("", 0, i);
    }
}
