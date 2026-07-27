// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Keys, Lanes, Specs} from "./Base.sol";
import {Specs} from "../Cursors.sol";
import {DebitAccountHook} from "../core/Settlement.sol";

using Executions for Execution;

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block; the default batch implementation handles the full request loop.
abstract contract DebitAccount is CommandBase, DebitAccountHook {
    uint private immutable descriptor;
    uint internal immutable debitAccountId;

    constructor() {
        (debitAccountId, descriptor) = command(
            "debitAccount",
            Specs.Empty,
            Specs.Amount,
            Specs.Balance,
            0,
            false,
            false
        );
    }

    /// @notice Override to customize request parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccount(
        bytes32 account,
        bytes calldata request
    ) internal virtual returns (Execution memory exec) {
        exec = openInput(request, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            debitAccount(account, asset, amount);
            exec.outputBalance(asset, amount);
        }

    }

    /// @notice Debit AMOUNT request blocks from the command account and output matching BALANCE blocks.
    /// @param input AMOUNT block stream.
    /// @return BALANCE block stream matching the debited amounts.
    /// @return Empty transaction stream.
    function debitAccount(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = debitAccount(account, input);

        return closeCommand(exec, account);
    }
}
