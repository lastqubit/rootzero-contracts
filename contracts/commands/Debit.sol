// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {AMOUNT, AMOUNT_KEY, Writer} from "../blocks/Schema.sol";
import {Data, DataRef} from "../Blocks.sol";
import {Writers} from "../blocks/Writers.sol";

string constant NAME = "debitAccountToBalance";

using Data for DataRef;
using Writers for Writer;

abstract contract DebitAccountToBalance is CommandBase {
    uint internal immutable debitAccountToBalanceId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, debitAccountToBalanceId, SETUP, BALANCES);
    }

    /// @dev Override to debit externally managed funds from `account`.
    /// Called once per AMOUNT block before a matching BALANCE is emitted.
    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    /// @dev Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccountToBalance(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(request, q, AMOUNT_KEY);

        while (q < end) {
            DataRef memory ref = Data.from(request, q);
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
