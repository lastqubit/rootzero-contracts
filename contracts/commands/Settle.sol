// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { Cursors, Cur, Tx } from "../Cursors.sol";
using Cursors for Cur;

string constant NAME = "settle";

abstract contract Settle is CommandBase {
    uint internal immutable settleId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", settleId, Channels.Transactions, Channels.Setup);
    }

    /// @dev Override to settle a single transaction block.
    /// Called once per TX block in state.
    function settle(Tx memory value) internal virtual;

    function settle(CommandContext calldata c) external payable onlyCommand(settleId, c.target) returns (bytes memory) {
        Cur memory state = cursor(c.state, 1);

        while (state.i < state.bound) {
            Tx memory value = state.unpackTxValue();
            settle(value);
        }

        state.complete();
        return "";
    }
}





