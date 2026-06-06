// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

/// @title PeerDenyAssets
/// @notice Peer that blocks a list of (asset, meta) pairs on behalf of a peer host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PeerDenyAssets is PeerBase, DenyAssetsHook {
    string private constant NAME = "peerDenyAssets";
    uint internal immutable peerDenyAssetsId = peerId(NAME);

    constructor() {
        emit Peer(host, peerDenyAssetsId, NAME, "1:0", Schemas.Asset, "", false);
    }

    /// @notice Execute the deny-assets peer call.
    /// @param request ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerDenyAssets(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = Cursors.init(request, 0, 1);

        while (assets.i < assets.len) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            denyAsset(asset, meta);
        }

        assets.complete();
        return "";
    }
}





