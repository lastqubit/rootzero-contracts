// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { Channels } from "../utils/Channels.sol";
import { Tx } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

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
        uint i = 0;
        while (i < c.state.length) {
            Block memory ref = Blocks.from(c.state, i);
            if (ref.key != Keys.Transaction) break;
            Tx memory value = ref.toTxValue();
            settle(value);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
