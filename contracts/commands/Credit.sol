// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

using Cursors for Cur;

abstract contract CreditAccountHook {
    /// @notice Override to credit externally managed funds to `account`.
    /// Called once per BALANCE block in state.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to credit.
    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title CreditAccount
/// @notice Command that delivers BALANCE state blocks to an account via a virtual hook.
/// Use for internally recording credits that have already been settled externally.
abstract contract CreditAccount is CommandBase, CreditAccountHook {
    uint internal immutable creditAccountId = commandId(this.creditAccount.selector);

    constructor() {
        emit Command(host, creditAccountId, "0:1:0", "", Keys.Balance, Keys.Empty, false);
        emit Labeled(creditAccountId, bytes32(0), "creditAccount");
    }

    /// @notice Credit each BALANCE block from the command state to the command account.
    /// @param c Command context; `c.state` must contain BALANCE blocks.
    /// @return Empty output state.
    function creditAccount(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        (Cur memory state, ) = Cursors.init(c.state, 1);

        while (state.i < state.len) {
            (bytes32 asset, uint amount) = state.unpackBalance();
            creditAccount(c.account, asset, amount);
        }

        state.complete();
        return "";
    }
}






