// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {Blocks, AMOUNT} from "../contracts/Blocks.sol";

string constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, myCommandId, SETUP, BALANCES);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        (bytes32 asset, bytes32 meta, uint amount) = Blocks.unpackAmountAt(c.request, 0);
        bytes memory out = Blocks.toBalanceBlock(asset, meta, amount);
        return out;
    }
}
