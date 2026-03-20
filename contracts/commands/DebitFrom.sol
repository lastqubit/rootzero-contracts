// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, SETUP} from "./Base.sol";
import {AMOUNT, AMOUNT_KEY, BlockRef, Writer} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
import {Writers} from "../blocks/Writers.sol";

bytes32 constant NAME = "debitAccountToBalance";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract DebitAccountToBalance is CommandBase {
    uint internal immutable debitAccountToBalanceId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, debitAccountToBalanceId, SETUP, BALANCES);
    }

    function debitAccountToBalance(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual returns (uint);

    function debitAccountToBalance(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(request, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.amountFrom(request, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(request);
            debitAccountToBalance(from, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            i = ref.end;
        }

        return writer.done();
    }

    function debitAccountToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(debitAccountToBalanceId, c.target) returns (bytes memory) {
        return debitAccountToBalance(c.account, c.request);
    }
}
