// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PeerBase} from "./Base.sol";
import {AllowanceHook} from "../commands/admin/Allowance.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

/// @title PeerAllowance
/// @notice Peer that lets a trusted peer host request or refresh its own allowance.
/// Each AMOUNT block in the request is scoped to the peer host and passed to the
/// shared allowance hook as a host-scoped allowance. Restricted to trusted peers.
abstract contract PeerAllowance is PeerBase, AllowanceHook {
    string private constant NAME = "peerAllowance";
    uint internal immutable peerAllowanceId = peerId(NAME);

    constructor() {
        emit Peer(host, peerAllowanceId, NAME, Schemas.Amount, false);
    }

    /// @notice Execute the allowance peer call.
    function peerAllowance(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, ) = cursor(request, 1);
        uint peer = caller();

        while (amounts.i < amounts.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = amounts.unpackAmount();
            allowance(peer, asset, meta, amount);
        }

        amounts.complete();
        return "";
    }
}
