// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { CreditAccountHook } from "../commands/Credit.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

/// @title PeerSettle
/// @notice Peer that consumes peer-supplied TRANSACTION blocks through debit and credit hooks.
/// Each TRANSACTION block calls `debitAccount` for `from` and `creditAccount` for `to`.
abstract contract PeerSettle is PeerBase, DebitAccountHook, CreditAccountHook {
    string private constant NAME = "peerSettle";
    uint internal immutable peerSettleId = peerId(NAME);

    constructor() {
        emit Peer(host, peerSettleId, NAME, "1:0", Schemas.Transaction, "", false);
    }

    /// @notice Execute the peer-settle call.
    function peerSettle(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory state, ) = Cursors.first(request, 1);

        while (state.i < state.len) {
            (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount) = state.unpackTransaction();
            if (from != 0) debitAccount(from, asset, meta, amount);
            if (to != 0) creditAccount(to, asset, meta, amount);
        }

        state.complete();
        return "";
    }
}
