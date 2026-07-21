// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Cursors, Cur, Writer, Writers } from "../Cursors.sol";
import { DebitAccountHook } from "../core/Settlement.sol";

using Cursors for Cur;
using Writers for Writer;

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block; the default batch implementation handles the full request loop.
abstract contract DebitAccount is CommandBase, DebitAccountHook {
    bytes32 private immutable descriptor;
    uint internal immutable debitAccountId;

    constructor() {
        (debitAccountId, descriptor) = command("debitAccount", Keys.Empty, Keys.Amount, Keys.Balance, 0, false, false);
    }

    /// @notice Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccount(bytes32 account, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory output = Writers.allocBalances(outputs);

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackAmount();
            debitAccount(account, asset, amount);
            output.appendBalance(asset, amount);
        }

        return end(output);
    }

    /// @notice Debit AMOUNT request blocks from the command account and output matching BALANCE blocks.
    /// @param c Command context; `c.input` must contain AMOUNT blocks.
    /// @return BALANCE block stream matching the debited amounts.
    /// @return Empty transaction stream.
    function debitAccount(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory, bytes memory) {
        return (debitAccount(c.account, c.input), "");
    }
}







