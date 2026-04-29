// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

string constant NAME = "peerAssetPull";

using Cursors for Cur;

abstract contract PeerAssetPullHook {
    /// @notice Override to process one incoming amount-based asset pull request from a remote host.
    /// @param peer Host node ID derived from the caller address.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @param amount Requested amount in the asset's native units.
    function peerAssetPull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title PeerAssetPull
/// @notice Peer that pulls requested asset amounts from a remote host into this one.
/// Each AMOUNT block in the request calls `peerAssetPull(peer, asset, meta, amount)`, where `peer`
/// is derived from `msg.sender`. Restricted to trusted peers.
abstract contract PeerAssetPull is PeerBase, PeerAssetPullHook {
    uint internal immutable peerAssetPullId = peerId(NAME);

    constructor() {
        emit Peer(host, peerAssetPullId, NAME, Schemas.Amount, false);
    }

    /// @notice Execute the asset-pull peer call.
    function peerAssetPull(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = cursor(request, 1);
        uint peer = caller();

        while (assets.i < assets.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = assets.unpackAmount();
            peerAssetPull(peer, asset, meta, amount);
        }

        assets.complete();
        return "";
    }
}
