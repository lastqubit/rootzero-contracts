// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {AMOUNT, AMOUNT_KEY, BlockRef, Writer} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
import {Writers} from "../blocks/Writers.sol";

string constant NAME = "debitAccountToBalance";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract DebitAccountToBalance is CommandBase {
    uint internal immutable debitAccountToBalanceId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, debitAccountToBalanceId, SETUP, BALANCES);
    }

    function debitAccountToBalance(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function debitAccountToBalance(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(request, q, AMOUNT_KEY);

        while (q < end) {
            BlockRef memory ref = Blocks.from(request, q);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(request);
            debitAccountToBalance(from, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
            q = ref.end;
        }

        return writer.done();
    }

    function debitAccountToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(debitAccountToBalanceId, c.target) returns (bytes memory) {
        return debitAccountToBalance(c.account, c.request);
    }
}
