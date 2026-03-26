// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { Channels } from "../utils/Channels.sol";
import { Writer } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
import { Writers } from "../blocks/Writers.sol";

string constant NAME = "debitAccountToBalance";

using Blocks for Block;
using Writers for Writer;

abstract contract DebitAccountToBalance is CommandBase {
    uint internal immutable debitAccountToBalanceId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, debitAccountToBalanceId, Channels.Setup, Channels.Balances);
    }

    /// @dev Override to debit externally managed funds from `account`.
    /// Called once per AMOUNT block before a matching BALANCE is emitted.
    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    /// @dev Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccountToBalance(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(request, q, Keys.Amount);

        while (q < end) {
            Block memory ref = Blocks.from(request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount();
            debitAccount(from, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            q = ref.cursor;
        }

        return writer.done();
    }

    function debitAccountToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(debitAccountToBalanceId, c.target) returns (bytes memory) {
        return debitAccountToBalance(c.account, c.request);
    }
}
