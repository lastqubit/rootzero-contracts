// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { TransferHook } from "../commands/Transfer.sol";
import { Cursors, Cur, Tx, Schemas } from "../Cursors.sol";

using Cursors for Cur;

string constant NAME = "peerSettle";

/// @title PeerSettle
/// @notice Peer that consumes peer-supplied TRANSACTION blocks through the shared transfer hook.
/// Each TRANSACTION block in the request calls `transfer(value)`. Restricted to trusted peers.
abstract contract PeerSettle is PeerBase, TransferHook {
    uint internal immutable peerSettleId = peerId(NAME);

    constructor() {
        emit Peer(host, NAME, Schemas.Transaction, peerSettleId, false);
    }

    /// @notice Execute the peer-settle call.
    function peerSettle(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory state, , ) = cursor(request, 1);

        while (state.i < state.bound) {
            Tx memory value = state.unpackTxValue();
            transfer(value);
        }

        state.complete();
        return "";
    }
}
