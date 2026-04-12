// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { Cursors, Cur, Schemas, Writer, Writers } from "../Cursors.sol";

string constant NAME = "debitAccount";

using Cursors for Cur;
using Writers for Writer;

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block; the default batch implementation handles the full request loop.
abstract contract DebitAccount is CommandBase {
    uint internal immutable debitAccountId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, debitAccountId, State.Empty, State.Balances);
    }

    /// @notice Override to debit externally managed funds from `account`.
    /// Called once per AMOUNT block before a matching BALANCE is emitted.
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to debit.
    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    /// @notice Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccount(bytes32 account, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, uint count, ) = cursor(request, 1);
        Writer memory writer = Writers.allocBalances(count);

        while (input.i < input.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();
            debitAccount(account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
        }

        return input.complete(writer);
    }

    function debitAccount(
        CommandContext calldata c
    ) external payable onlyCommand(debitAccountId, c.target) returns (bytes memory) {
        return debitAccount(c.account, c.request);
    }
}






