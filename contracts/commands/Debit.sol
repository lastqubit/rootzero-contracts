// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {DebitAccountHook} from "../core/Settlement.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Sizes} from "../codec/Specs.sol";
import {Decoders} from "../codec/Decoders.sol";
import {Cur} from "../utils/Cursors.sol";

using Executions for Execution;
using Decoders for Cur;

/// @title DebitAccount
/// @notice Command that deducts AMOUNT blocks from an account and emits matching BALANCE state.
/// Use for internally recording debits. The virtual `debitAccount` hook is called once per
/// AMOUNT block.
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

    /// @notice Debit AMOUNT input blocks from the command account and output matching BALANCE blocks.
    /// @param input AMOUNT block stream.
    /// @return BALANCE block stream matching the debited amounts.
    /// @return Empty transaction stream.
    function debitAccount(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            debitAccount(account, asset, amount);
            exec.outputBalance(asset, amount);
        }

        return close(exec, account);
    }
}

/// @title InternalDebitAccount
/// @notice Extends the advertised debit-account command with memory-state pipeline dispatch.
/// @dev This adapter is not a separate command. It uses the command ID and account hook
/// inherited from `DebitAccount` while accepting the state location used by `Pipeline`.
abstract contract InternalDebitAccount is DebitAccount {
    /// @notice Execute the inherited debit-account command from an internal pipeline.
    /// @param account Account whose funds are debited.
    /// @param state Empty pipeline state required by the command schema.
    /// @param input AMOUNT block stream.
    /// @param value Native value assigned to the command; must be zero.
    /// @return output BALANCE block stream matching the debited amounts.
    /// @return transactions Empty transaction stream.
    function executeDebitAccount(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory, bytes memory) {
        if (value != 0) revert ValueNotAllowed();
        if (state.length != 0) revert Executions.ZeroStride();
        if (input.length == 0) revert Blocks.EmptyRun();

        Cur memory cur = Decoders.wrap(input);
        uint count = input.length / Sizes.Amount;
        bytes memory output = new bytes(count * Sizes.Balance);
        uint i;

        while (cur.more()) {
            (bytes32 asset, uint amount) = cur.unpackAmount();
            debitAccount(account, asset, amount);
            Blocks.writeBalance(output, i, asset, amount);
            i += Sizes.Balance;
        }

        return (output, "");
    }
}
