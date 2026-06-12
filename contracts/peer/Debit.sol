// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Forms } from "../Cursors.sol";

using Cursors for Cur;

interface IPeerDebitFrom {
    function peerDebitFrom(bytes calldata request) external returns (bytes memory);
}

/// @title PeerDebitFrom
/// @notice Peer that lets a trusted peer debit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `debitAccount` for its account.
abstract contract PeerDebitFrom is PeerBase, DebitAccountHook, IPeerDebitFrom {
    uint internal immutable peerDebitFromId = peerId(this.peerDebitFrom.selector);

    constructor() {
        emit Peer(host, peerDebitFromId, "1:0", Forms.AccountAmount, "", false);
        emit Labeled(peerDebitFromId, bytes32(0), "peerDebitFrom");
    }

    /// @notice Execute the peer-debit call.
    /// @param request ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerDebitFrom(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, , ) = Cursors.init(request, 1);

        while (amounts.i < amounts.len) {
            (bytes32 account, bytes32 asset, bytes32 meta, uint amount) = amounts.unpackAccountAmount();
            debitAccount(account, asset, meta, amount);
        }

        amounts.complete();
        return "";
    }
}
