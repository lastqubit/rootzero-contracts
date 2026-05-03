// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
using Cursors for Cur;

abstract contract WithdrawHook {
    /// @notice Override to send funds to `account`.
    /// Called once per BALANCE block in state.
    /// @param account Destination account identifier (resolved from ACCOUNT block or caller).
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
        emit Command(host, withdrawId, NAME, Schemas.Account, Keys.Balance, Keys.Empty, false);
    }

    function withdraw(
        CommandContext calldata c
    ) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);
        bytes32 to = Cursors.resolveAccount(c.request, c.account);

        while (state.i < state.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            withdraw(to, asset, meta, amount);
        }

        state.complete();
        return "";
    }
}






