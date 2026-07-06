// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { CreditAccountHook } from "../commands/Credit.sol";
import { Cursors, Cur, Forms } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortCreditAccount
/// @notice Port that lets a trusted peer credit supplied accounts directly.
/// Each ACCOUNT_AMOUNT block calls `creditAccount` for its account.
abstract contract PortCreditAccount is PortBase, CreditAccountHook {
    uint internal immutable portCreditAccountId = portId(this.portCreditAccount.selector);

    constructor() {
        emit Port(host, portCreditAccountId, "1:0", Forms.AccountAmount, "", false);
        emit Labeled(portCreditAccountId, bytes32(0), "portCreditAccount");
    }

    /// @notice Execute the port-credit call.
    /// @param data ACCOUNT_AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portCreditAccount(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory amounts, ) = Cursors.init(data, 1);

        while (amounts.i < amounts.len) {
            (bytes32 account, bytes32 asset, uint amount) = amounts.unpackAccountAmount();
            creditAccount(account, asset, amount);
        }

        amounts.complete();
        return "";
    }
}
