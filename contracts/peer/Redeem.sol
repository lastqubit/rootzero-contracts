// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

interface IPeerRedeemBalance {
    function peerRedeemBalance(bytes calldata request) external returns (bytes memory);
}

abstract contract RedeemBalanceHook {
    /// @notice Override to redeem one balance claim from a peer host into local assets.
    /// @param peer Peer host node ID for this request.
    /// @param asset Asset identifier to redeem locally.
    /// @param amount Amount to redeem in the asset's native units.
    function redeemBalance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title PeerRedeemBalance
/// @notice Peer that redeems balance state from a peer host into local assets.
/// Each BALANCE block in the request calls `redeemBalance(peer, asset, amount)`.
/// Restricted to trusted peers.
abstract contract PeerRedeemBalance is PeerBase, RedeemBalanceHook, IPeerRedeemBalance {
    uint internal immutable peerRedeemBalanceId = peerId(this.peerRedeemBalance.selector);

    constructor() {
        emit Peer(host, peerRedeemBalanceId, "1:0", Schemas.Balance, "", false);
        emit Labeled(peerRedeemBalanceId, bytes32(0), "peerRedeemBalance");
    }

    /// @notice Execute the balance redemption peer call.
    /// @param request BALANCE block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerRedeemBalance(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory input, , ) = Cursors.init(request, 1);
        uint peer = caller();

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackBalance();
            redeemBalance(peer, asset, amount);
        }

        input.complete();
        return "";
    }
}
