// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, SETUP} from "./Base.sol";
import {AMOUNT, AMOUNT_KEY, BlockRef, Writer} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
import {Writers} from "../blocks/Writers.sol";

string constant NAME = "deposit";

using Blocks for BlockRef;
using Writers for Writer;

// @dev Use `deposit` for externally sourced assets; use `debitAccountToBalance` for internal balance deductions.
abstract contract Deposit is CommandBase {
    uint internal immutable depositId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, depositId, SETUP, BALANCES);
    }

    function deposit(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual;

    function deposit(
        CommandContext calldata c
    ) external payable onlyCommand(depositId, c.target) returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint next) = Writers.allocBalancesFrom(c.request, i, AMOUNT_KEY);

        while (i < next) {
            BlockRef memory ref = Blocks.amountFrom(c.request, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            deposit(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            i = ref.end;
        }

        return writer.done();
    }
}
