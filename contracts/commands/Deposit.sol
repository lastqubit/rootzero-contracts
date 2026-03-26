// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, SETUP } from "../utils/Channels.sol";
import { Writer } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
import { Writers } from "../blocks/Writers.sol";

string constant NAME = "deposit";

using Blocks for Block;
using Writers for Writer;

// @dev Use `deposit` for externally sourced assets; use `debitAccountToBalance` for internal balance deductions.
abstract contract Deposit is CommandBase {
    uint internal immutable depositId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, depositId, SETUP, BALANCES);
    }

    /// @dev Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block and followed by a matching BALANCE output.
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
        (Writer memory writer, uint next) = Writers.allocBalancesFrom(c.request, q, Keys.Amount);

        while (q < next) {
            Block memory ref = Blocks.from(c.request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount();
            deposit(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            q = ref.cursor;
        }

        return writer.done();
    }
}
