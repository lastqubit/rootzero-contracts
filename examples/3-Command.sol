// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {Blocks, AMOUNT} from "../contracts/Blocks.sol";

string constant NAME = "myCommand";

string constant REQUEST = AMOUNT;

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    event MyEvent(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, bytes out);

    constructor() {
        emit Command(host, NAME, REQUEST, myCommandId, SETUP, BALANCES);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        (bytes32 asset, bytes32 meta, uint amount) = Blocks.unpackAmountAt(c.request, 0);
        bytes memory out = Blocks.toBalanceBlock(asset, meta, amount);
        emit MyEvent(c.account, asset, meta, amount, out);
        return out;
    }
}
