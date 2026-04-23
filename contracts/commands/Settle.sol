// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { Cursors, Cur, Tx } from "../Cursors.sol";
import { TransferHook } from "./Transfer.sol";
using Cursors for Cur;

string constant NAME = "settle";

/// @title Settle
/// @notice Command that consumes each TRANSACTION state block and settles it through the shared transfer hook.
/// Produces no output state.
abstract contract Settle is CommandBase, TransferHook {
    uint internal immutable settleId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", settleId, State.Transactions, State.Empty, false);
    }

    function settle(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);

        while (state.i < state.bound) {
            Tx memory value = state.unpackTxValue();
            transfer(value);
        }

        state.complete();
        return "";
    }
}






