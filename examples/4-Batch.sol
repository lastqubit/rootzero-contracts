// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {Blocks, BlockRef, Writers, Writer, AMOUNT, AMOUNT_KEY} from "../contracts/Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

bytes32 constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    event MyEvent(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, bytes out);

    constructor() {
        emit Command(host, NAME, AMOUNT, myCommandId, SETUP, BALANCES);
    }

    function handle(bytes32 account, bytes32 asset, bytes32 meta, uint amount) private returns (bytes memory out) {
        out = Blocks.toBalanceBlock(asset, meta, amount);
        emit MyEvent(account, asset, meta, amount, out);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.amountFrom(c.request, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            handle(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            i = ref.end;
        }

        return writer.done();
    }
}
