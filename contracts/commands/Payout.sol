// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Keys} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

abstract contract PayoutHook {
    /// @notice Override to pay `amount` from `account` to `to`.
    /// Called once per paired BALANCE state block and ACCOUNT request block.
    /// @param account Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to pay out.
    function payout(bytes32 account, bytes32 to, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title Payout
/// @notice Command that sinks BALANCE state blocks to matching ACCOUNT request blocks.
/// Each BALANCE block is paired with one ACCOUNT block at the same position.
abstract contract Payout is CommandBase, PayoutHook {
    string private constant NAME = "payout";

    uint internal immutable payoutId = commandId(NAME);

    constructor() {
        emit Command(host, payoutId, NAME, "1:1:0", Schemas.Account, Keys.Balance, Keys.Empty, false);
    }

    function payout(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory state, uint groups) = cursor(c.state, 1);
        Cur memory request = cursor(c.request, 1, groups);

        while (state.i < state.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = state.unpackBalance();
            bytes32 to = request.unpackAccount();
            payout(c.account, to, asset, meta, amount);
        }

        state.close();
        return "";
    }
}
