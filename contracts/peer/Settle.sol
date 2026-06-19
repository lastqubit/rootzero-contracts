// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { CreditAccountHook } from "../commands/Credit.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

interface IPeerSettle {
    function peerSettle(bytes calldata request) external returns (bytes memory);
}

/// @title PeerSettle
/// @notice Peer that consumes peer-supplied TRANSACTION blocks through debit and credit hooks.
/// Each TRANSACTION block calls `debitAccount` for `from` and `creditAccount` for `to`.
abstract contract PeerSettle is PeerBase, DebitAccountHook, CreditAccountHook, IPeerSettle {
    uint internal immutable peerSettleId = peerId(this.peerSettle.selector);

    constructor() {
        emit Peer(host, peerSettleId, "1:0", Schemas.Transaction, "", false);
        emit Labeled(peerSettleId, bytes32(0), "peerSettle");
    }

    /// @notice Execute the peer-settle call.
    /// @param request TRANSACTION block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerSettle(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory state, , ) = Cursors.init(request, 1);

        while (state.i < state.len) {
            (bytes32 from, bytes32 to, bytes32 asset, uint amount) = state.unpackTransaction();
            if (from != 0) debitAccount(from, asset, amount);
            if (to != 0) creditAccount(to, asset, amount);
        }

        state.complete();
        return "";
    }
}
