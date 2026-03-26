// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "peerDenyAssets";

abstract contract PeerDenyAssets is PeerBase {
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerDenyAssetsId);
    }

    function peerDenyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerDenyAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            Block memory ref = Blocks.from(request, q);
            if (ref.key != Keys.Asset) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            peerDenyAsset(asset, meta);
            q = ref.cursor;
        }
        return done(0, q);
    }
}
