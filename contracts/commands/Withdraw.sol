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
    /// @param meta Asset metadata slot.
    /// @param amount Amount to deliver.
    function withdraw(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title Withdraw
/// @notice Command that delivers BALANCE state blocks to an external destination.
/// Use `withdraw` for assets being sent outside the protocol (e.g. ERC-20 transfers, ETH sends).
/// For internal balance credits, use `creditAccount` instead.
abstract contract Withdraw is CommandBase, WithdrawHook {
    string private constant NAME = "withdraw";

    uint internal immutable withdrawId = commandId(NAME);

    constructor() {
        emit Command(host, withdrawId, NAME, "0:1:0", "", Keys.Balance, Keys.Empty, false, false);
    }

    function withdraw(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        (Cur memory state, , ) = Cursors.init(c.state, 0, 1);

        while (state.i < state.len) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            withdraw(c.account, asset, meta, amount);
        }

        state.complete();
        return "";
    }
}






