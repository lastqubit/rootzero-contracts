// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

abstract contract BalancePullHook {
    /// @notice Override to process one incoming balance-based pull request from a peer host.
    /// @param peer Peer host node ID for this request.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @param amount Requested amount in the asset's native units.
    function balancePull(uint peer, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title PeerBalancePull
/// @notice Peer that pulls requested balances from a peer host into this one.
/// Each BALANCE block in the request calls `balancePull(peer, asset, meta, amount)`.
/// Restricted to trusted peers.
abstract contract PeerBalancePull is PeerBase, BalancePullHook {
    string private constant NAME = "peerBalancePull";
    uint internal immutable peerBalancePullId = peerId(NAME);

    constructor() {
        emit Peer(host, peerBalancePullId, NAME, "1:0", Schemas.Balance, "", false);
    }

    /// @notice Execute the balance-pull peer call.
    function peerBalancePull(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = Cursors.first(request, 1);
        uint peer = caller();

        while (input.i < input.len) {
            (bytes32 asset, bytes32 meta, uint amount) = input.unpackBalance();
            balancePull(peer, asset, meta, amount);
        }

        input.complete();
        return "";
    }
}
