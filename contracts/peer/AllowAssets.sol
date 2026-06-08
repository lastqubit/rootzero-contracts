// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { AllowAssetsHook } from "../commands/admin/AllowAssets.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

/// @title PeerAllowAssets
/// @notice Peer that permits a list of (asset, meta) pairs on behalf of a peer host.
/// Each ASSET block in the request calls `allowAsset`. Restricted to trusted peers.
abstract contract PeerAllowAssets is PeerBase, AllowAssetsHook {
    uint internal immutable peerAllowAssetsId = peerId(this.peerAllowAssets.selector);

    constructor() {
        emit Peer(host, peerAllowAssetsId, "1:0", Schemas.Asset, "", false);
        emit Labeled(peerAllowAssetsId, bytes32(0), "peerAllowAssets");
    }

    /// @notice Execute the allow-assets peer call.
    /// @param request ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerAllowAssets(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = Cursors.init(request, 0, 1);

        while (assets.i < assets.len) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            allowAsset(asset, meta);
        }

        assets.complete();
        return "";
    }
}





