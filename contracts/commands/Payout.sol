// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Keys} from "./Base.sol";
import {Cursors, Cur} from "../Cursors.sol";

using Cursors for Cur;

abstract contract PayoutHook {
    /// @notice Override to pay `amount` from `account` to `to`.
    /// Called once per paired BALANCE state block and ACCOUNT request block.
    /// @param account Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to pay out.
    function payout(bytes32 account, bytes32 to, bytes32 asset, uint amount) internal virtual;
}

/// @title Payout
/// @notice Command that sinks BALANCE state blocks to matching ACCOUNT request blocks.
/// Each BALANCE block is paired with one ACCOUNT block at the same position.
abstract contract Payout is CommandBase, PayoutHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("payout", Keys.Balance, Keys.Account, Keys.Empty, 0, false, false);
    }

    /// @notice Pay out BALANCE state blocks to matching ACCOUNT request blocks.
    /// @param c Command context; `c.state` must contain BALANCE blocks and `c.request` matching ACCOUNT blocks.
    /// @return Empty output state.
    function payout(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory input, Cur memory state, ) = openCommand(c, descriptor);

        while (state.i < state.len) {
            (bytes32 asset, uint amount) = state.unpackBalance();
            payout(c.account, input.unpackAccount(), asset, amount);
        }
        return "";
    }
}
