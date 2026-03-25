// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {TRANSACTIONS, SETUP} from "../utils/Channels.sol";
import {BlockRef, TX_KEY, Tx} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "settle";

abstract contract Settle is CommandBase {
    uint internal immutable settleId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", settleId, TRANSACTIONS, SETUP);
    }

    function settle(Tx memory value) internal virtual;

    function settle(CommandContext calldata c) external payable onlyCommand(settleId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.state.length) {
            BlockRef memory ref = Blocks.from(c.state, i);
            if (ref.key != TX_KEY) break;
            Tx memory value = ref.toTxValue(c.state);
            settle(value);
            i = ref.end;
        }
        return done(0, i);
    }
}
