// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
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
        uint q = 0;
        (Writer memory writer, uint next) = Writers.allocBalancesFrom(c.request, q, AMOUNT_KEY);

        while (q < next) {
            BlockRef memory ref = Blocks.from(c.request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(c.request);
            deposit(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            q = ref.end;
        }

        return writer.done();
    }
}
