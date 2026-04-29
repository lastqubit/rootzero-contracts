// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";
using Cursors for Cur;

string constant NAME = "burn";

abstract contract BurnHook {
    /// @notice Override to burn or consume the provided balance amount.
    /// Called once per BALANCE block in state.
    /// @param account Caller's account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to burn.
    /// @return Amount actually burned (may differ from `amount` for partial burns).
    function burn(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual returns (uint);
}

/// @title Burn
/// @notice Command that irreversibly destroys each BALANCE state block via a virtual hook.
/// Produces no output state.
abstract contract Burn is CommandBase, BurnHook {
    uint internal immutable burnId = commandId(NAME);

    constructor() {
        emit Command(host, burnId, NAME, "", Keys.Balance, Keys.Empty, false);
    }

    function burn(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);

        while (state.i < state.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            burn(c.account, asset, meta, amount);
        }

        state.complete();
        return "";
    }
}






