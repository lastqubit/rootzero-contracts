// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PeerBase } from "./Base.sol";
import { CreditAccountHook } from "../commands/Credit.sol";
import { Cursors, Cur, Forms } from "../Cursors.sol";

using Cursors for Cur;

interface IPeerCreditTo {
    function peerCreditTo(bytes calldata request) external returns (bytes memory);
}

/// @title PeerCreditTo
/// @notice Peer that lets a trusted peer credit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `creditAccount` for its account.
abstract contract PeerCreditTo is PeerBase, CreditAccountHook, IPeerCreditTo {
    uint internal immutable peerCreditToId = peerId(this.peerCreditTo.selector);

    constructor() {
        emit Peer(host, peerCreditToId, "1:0", Forms.AccountAmount, "", false);
        emit Labeled(peerCreditToId, bytes32(0), "peerCreditTo");
    }

    /// @notice Execute the peer-credit call.
    /// @param request ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function peerCreditTo(bytes calldata request) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, , ) = Cursors.init(request, 1);

        while (amounts.i < amounts.len) {
            (bytes32 account, bytes32 asset, bytes32 meta, uint amount) = amounts.unpackAccountAmount();
            creditAccount(account, asset, meta, amount);
        }

        amounts.complete();
        return "";
    }
}
