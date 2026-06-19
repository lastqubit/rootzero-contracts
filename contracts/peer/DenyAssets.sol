// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

interface IPeerDenyAssets {
    function peerDenyAssets(bytes calldata request) external returns (bytes memory);
}

/// @title PeerDenyAssets
/// @notice Peer that blocks a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PeerDenyAssets is PeerBase, DenyAssetsHook, IPeerDenyAssets {
    uint internal immutable peerDenyAssetsId = peerId(this.peerDenyAssets.selector);

    constructor() {
        emit Peer(host, peerDenyAssetsId, "1:0", Schemas.Asset, "", false);
        emit Labeled(peerDenyAssetsId, bytes32(0), "peerDenyAssets");
    }

    /// @notice Execute the deny-assets peer call.
    /// @param request ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerDenyAssets(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = Cursors.init(request, 1);

        while (assets.i < assets.len) {
            bytes32 asset = assets.unpackAsset();
            denyAsset(asset);
        }

        assets.complete();
        return "";
    }
}





