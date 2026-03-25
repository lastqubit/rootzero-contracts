// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {ASSET, ASSET_KEY, BlockRef} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "peerDenyAssets";

abstract contract PeerDenyAssets is PeerBase {
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, ASSET, peerDenyAssetsId);
    }

    function peerDenyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerDenyAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            BlockRef memory ref = Blocks.from(request, q);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset(request);
            peerDenyAsset(asset, meta);
            q = ref.end;
        }
        return done(0, q);
    }
}
