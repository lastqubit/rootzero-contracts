// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { Cursors, Cur, Tx } from "../Cursors.sol";
using Cursors for Cur;

string constant NAME = "settle";

/// @title Settle
/// @notice Command that settles each TRANSACTION state block via a virtual hook.
/// Produces no output state.
abstract contract Settle is CommandBase {
    uint internal immutable settleId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", settleId, State.Transactions, State.Empty);
    }

    /// @notice Override to settle a single transaction block.
    /// Called once per TRANSACTION block in state.
    /// @param value Decoded transaction (from, to, asset, meta, amount).
    function settle(Tx memory value) internal virtual;

    function settle(CommandContext calldata c) external payable onlyCommand(settleId, c.target) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);

        while (state.i < state.bound) {
            Tx memory value = state.unpackTxValue();
            settle(value);
        }

        state.complete();
        return "";
    }
}





