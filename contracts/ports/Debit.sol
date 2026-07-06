// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { DebitAccountHook } from "../commands/Debit.sol";
import { Cursors, Cur, Forms } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortDebitAccount
/// @notice Port that lets a trusted peer debit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `debitAccount` for its account.
abstract contract PortDebitAccount is PortBase, DebitAccountHook {
    uint internal immutable portDebitAccountId = portId(this.portDebitAccount.selector);

    constructor() {
        emit Port(host, portDebitAccountId, "1:0", Forms.AccountAmount, "", false);
        emit Labeled(portDebitAccountId, bytes32(0), "portDebitAccount");
    }

    /// @notice Execute the port-debit call.
    /// @param data ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDebitAccount(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, ) = Cursors.init(data, 1);

        while (amounts.i < amounts.len) {
            (bytes32 account, bytes32 asset, uint amount) = amounts.unpackAccountAmount();
            debitAccount(account, asset, amount);
        }

        amounts.complete();
        return "";
    }
}
