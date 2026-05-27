// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { Cursors, Cur, Schemas, Tx } from "../Cursors.sol";

using Cursors for Cur;

abstract contract PeerSettleHook {
    /// @notice Override to settle the source side of a peer-supplied transaction record.
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to settle from the source account.
    function settleFrom(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    /// @notice Override to settle the destination side of a peer-supplied transaction record.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to settle to the destination account.
    function settleTo(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title PeerSettle
/// @notice Peer that consumes peer-supplied TRANSACTION blocks through settlement hooks.
/// Each TRANSACTION block in the request calls `settleFrom` and `settleTo`. Restricted to trusted peers.
abstract contract PeerSettle is PeerBase, PeerSettleHook {
    string private constant NAME = "peerSettle";
    uint internal immutable peerSettleId = peerId(NAME);

    constructor() {
        emit Peer(host, peerSettleId, NAME, "1:0", Schemas.Transaction, "", false);
    }

    /// @notice Execute the peer-settle call.
    function peerSettle(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory state, ) = cursor(request, 1);

        while (state.i < state.bound) {
            Tx memory txn = state.unpackTxValue();
            if (txn.from != 0) settleFrom(txn.from, txn.asset, txn.meta, txn.amount);
            if (txn.to != 0) settleTo(txn.to, txn.asset, txn.meta, txn.amount);
        }

        state.close();
        return "";
    }
}
