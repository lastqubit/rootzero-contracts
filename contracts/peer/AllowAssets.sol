// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

string constant NAME = "peerAllowAssets";

/// @title PeerAllowAssets
/// @notice Peer that permits a list of (asset, meta) pairs on behalf of a remote host.
/// Each ASSET block in the request calls `peerAllowAsset`. Restricted to trusted peers.
abstract contract PeerAllowAssets is PeerBase {
    uint internal immutable peerAllowAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Asset, peerAllowAssetsId);
    }

    /// @notice Override to permit a single (asset, meta) pair.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @return True if the asset was newly allowed, false if it was already allowed.
    function peerAllowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    /// @notice Execute the allow-assets peer call.
    function peerAllowAssets(bytes calldata request) external payable onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = cursor(request, 1);

        while (assets.i < assets.bound) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            peerAllowAsset(asset, meta);
        }

        assets.complete();
        return "";
    }
}





