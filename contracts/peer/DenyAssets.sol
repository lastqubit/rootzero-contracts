// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

string constant NAME = "peerDenyAssets";

abstract contract PeerDenyAssets is PeerBase {
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerDenyAssetsId);
    }

    function peerDenyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function peerDenyAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory assets, ) = cursor(request, 1);

        while (assets.i < assets.bound) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            peerDenyAsset(asset, meta);
        }

        assets.complete();
        return "";
    }
}





