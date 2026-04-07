// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cursor, Keys, Schemas} from "../Cursors.sol";

using Cursors for Cursor;

string constant NAME = "peerDenyAssets";

abstract contract PeerDenyAssets is PeerBase {
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerDenyAssetsId);
    }

    function peerDenyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerDenyAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        Cursor memory assets = Cursors.openRun(request, 0, Keys.Asset, 1);
        while (assets.i < assets.end) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            peerDenyAsset(asset, meta);
        }
        return assets.complete();
    }
}




