// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

string constant NAME = "peerDenyAssets";

/// @title PeerDenyAssets
/// @notice Peer that blocks a list of (asset, meta) pairs on behalf of a remote host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PeerDenyAssets is PeerBase, DenyAssetsHook {
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerDenyAssetsId, false);
    }

    /// @notice Execute the deny-assets peer call.
    function peerDenyAssets(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = cursor(request, 1);

        while (assets.i < assets.bound) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            denyAsset(asset, meta);
        }

        assets.complete();
        return "";
    }
}





