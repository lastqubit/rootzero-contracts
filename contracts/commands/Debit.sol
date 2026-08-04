// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {DebitAccountHook} from "../core/Settlement.sol";

using Executions for Execution;

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block; the default batch implementation handles the full input loop.
abstract contract DebitAccount is CommandBase, DebitAccountHook {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("debitAccount", Specs.Empty, Specs.Amount, Specs.Balance, 0, false, false);
    }

    /// @notice Return the registered DEBIT_ACCOUNT command ID.
    function debitAccountId() internal view returns (uint) {
        return id;
    }

    /// @notice Override to customize input parsing or batching for debits.
    /// The default implementation iterates AMOUNT blocks, calls
    /// `debitAccount`, and emits matching BALANCE blocks.
    function debitAccount(bytes32 account, bytes calldata input) internal virtual returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            debitAccount(account, asset, amount);
            exec.outputBalance(asset, amount);
        }

        return close(exec, account);
    }

    /// @notice Debit AMOUNT input blocks from the command account and output matching BALANCE blocks.
    /// @param input AMOUNT block stream.
    /// @return BALANCE block stream matching the debited amounts.
    /// @return Empty transaction stream.
    function debitAccount(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        return debitAccount(account, input);
    }
}
