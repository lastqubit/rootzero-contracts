// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../Cursors.sol";

using Cursors for Cursor;

string constant NAME = "peerAllowAssets";

abstract contract PeerAllowAssets is PeerBase {
    uint internal immutable peerAllowAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerAllowAssetsId);
    }

    function peerAllowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerAllowAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        Cursor memory assets = Cursors.openRun(request, 0, Keys.Asset, 1);
        while (assets.i < assets.end) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            peerAllowAsset(asset, meta);
        }
        return assets.complete();
    }
}




