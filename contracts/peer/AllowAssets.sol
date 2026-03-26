// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {ASSET, ASSET_KEY} from "../blocks/Schema.sol";
import {Data, DataRef} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "peerAllowAssets";

abstract contract PeerAllowAssets is PeerBase {
    uint internal immutable peerAllowAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, ASSET, peerAllowAssetsId);
    }

    function peerAllowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerAllowAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        uint q = 0;
        while (q < request.length) {
            DataRef memory ref = Data.from(request, q);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            peerAllowAsset(asset, meta);
            q = ref.cursor;
        }
        return done(0, q);
    }
}
