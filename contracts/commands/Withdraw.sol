// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";
using Cursors for Cur;

abstract contract WithdrawHook {
    /// @notice Override to send funds to `account`.
    /// Called once per BALANCE block in state.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to deliver.
    function withdraw(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title Withdraw
/// @notice Command that delivers BALANCE state blocks to an external destination.
/// Use `withdraw` for assets being sent outside the protocol (e.g. ERC-20 transfers, ETH sends).
/// For internal balance credits, use `creditAccount` instead.
abstract contract Withdraw is CommandBase, WithdrawHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("withdraw", Keys.Balance, Keys.Empty, Keys.Empty, 0, false, false);
    }

    /// @notice Withdraw each BALANCE block from the command state to the command account.
    /// @param c Command context; `c.state` must contain BALANCE blocks.
    /// @return Empty output state.
    function withdraw(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        (Cur memory state, ) = openState(c.state, descriptor);

        while (state.i < state.len) {
            (bytes32 asset, uint amount) = state.unpackBalance();
            withdraw(c.account, asset, amount);
        }
        return "";
    }
}






