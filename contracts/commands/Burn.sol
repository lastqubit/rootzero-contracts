// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";
using Cursors for Cur;

abstract contract BurnHook {
    /// @notice Override to burn or consume the provided balance amount.
    /// Called once per BALANCE block in state.
    /// @param account Caller's account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to burn.
    /// @return Amount actually burned (may differ from `amount` for partial burns).
    function burn(bytes32 account, bytes32 asset, uint amount) internal virtual returns (uint);
}

/// @title Burn
/// @notice Command that irreversibly destroys each BALANCE state block via a virtual hook.
/// Produces no output state.
abstract contract Burn is CommandBase, BurnHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("burn", Keys.Balance, Keys.Empty, Keys.Empty, 0, false, false);
    }

    /// @notice Burn each BALANCE block from the command state.
    /// @param c Command context; `c.state` must contain BALANCE blocks.
    /// @return state Empty output state.
    /// @return transactions Empty transaction stream.
    function burn(CommandContext calldata c) external onlyCommand returns (bytes memory state, bytes memory transactions) {
        (Cur memory stateCur, ) = openState(c.state, descriptor);

        while (stateCur.i < stateCur.len) {
            (bytes32 asset, uint amount) = stateCur.unpackBalance();
            burn(c.account, asset, amount);
        }
        return ("", "");
    }
}






