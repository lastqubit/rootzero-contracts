// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {AssetAmount, Blocks, BlockRef, Writers, Writer, AMOUNT, AMOUNT_KEY} from "../contracts/Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

string constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, myCommandId, SETUP, BALANCES);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.amountFrom(c.request, i);
            AssetAmount memory value = ref.toAmountValue(c.request);
            writer.appendBalance(value);
            i = ref.end;
        }

        return writer.done();
    }
}
