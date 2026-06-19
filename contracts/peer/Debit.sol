// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Forms } from "../Cursors.sol";

using Cursors for Cur;

interface IPeerDebitAccount {
    function peerDebitAccount(bytes calldata request) external returns (bytes memory);
}

/// @title PeerDebitAccount
/// @notice Peer that lets a trusted peer debit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `debitAccount` for its account.
abstract contract PeerDebitAccount is PeerBase, DebitAccountHook, IPeerDebitAccount {
    uint internal immutable peerDebitAccountId = peerId(this.peerDebitAccount.selector);

    constructor() {
        emit Peer(host, peerDebitAccountId, "1:0", Forms.AccountAmount, "", false);
        emit Labeled(peerDebitAccountId, bytes32(0), "peerDebitAccount");
    }

    /// @notice Execute the peer-debit call.
    /// @param request ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerDebitAccount(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, , ) = Cursors.init(request, 1);

        while (amounts.i < amounts.len) {
            (bytes32 account, bytes32 asset, uint amount) = amounts.unpackAccountAmount();
            debitAccount(account, asset, amount);
        }

        amounts.complete();
        return "";
    }
}
