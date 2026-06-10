// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Cursors, Cur, Schemas, Writer, Writers } from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract DebitAccountHook {
    /// @notice Override to debit externally managed funds from `account`.
    /// Called once per AMOUNT block before a matching BALANCE is emitted.
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount to debit.
    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block; the default batch implementation handles the full request loop.
abstract contract DebitAccount is CommandBase, DebitAccountHook {
    uint internal immutable debitAccountId = commandId(this.debitAccount.selector);

    constructor() {
        emit Command(host, debitAccountId, "1:0:1", Schemas.Amount, Keys.Empty, Keys.Balance, false);
        emit Labeled(debitAccountId, bytes32(0), "debitAccount");
    }

    /// @notice Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccount(bytes32 account, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, uint groups, ) = Cursors.init(request, 1);
        Writer memory writer = Writers.allocBalances(groups);

        while (input.i < input.len) {
            (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();
            debitAccount(account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
        }

        input.complete();
        return writer.finish();
    }

    /// @notice Debit AMOUNT request blocks from the command account and output matching BALANCE blocks.
    /// @param c Command context; `c.request` must contain AMOUNT blocks.
    /// @return BALANCE block stream matching the debited amounts.
    function debitAccount(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        return debitAccount(c.account, c.request);
    }
}







