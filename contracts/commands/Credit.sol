// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";
import {CreditAccountHook} from "../core/Settlement.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Reader, Readers} from "../codec/Readers.sol";

using Executions for Execution;
using Readers for Reader;

/// @title CreditAccount
/// @notice Command that delivers BALANCE state blocks to an account via a virtual hook.
/// Use for internally recording credits that have already been posted externally.
abstract contract CreditAccount is CommandBase, CreditAccountHook {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("creditAccount", Specs.Balance, Specs.Empty, Specs.Empty, 0, 0);
    }

    /// @notice Return the registered CREDIT_ACCOUNT command ID.
    function creditAccountId() internal view returns (uint) {
        return id;
    }

    /// @notice Credit each BALANCE block from the command state to the command account.
    /// @param context Command context carrying the BALANCE state stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function creditAccount(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
            creditAccount(exec.account, asset, amount);
        }

        return closeCommand(exec);
    }
}

/// @title CreditAccountInternal
/// @notice Extends the advertised credit-account command with memory-state pipeline dispatch.
/// @dev This adapter is not a separate command. It uses the command ID and account hook
/// inherited from `CreditAccount` while accepting the state location used by `Pipeline`.
abstract contract CreditAccountInternal is CreditAccount {
    /// @notice Execute the inherited credit-account command from an internal pipeline.
    /// @param account Account credited by each balance.
    /// @param state BALANCE block stream held in pipeline memory.
    /// @param input Empty input required by the command schema.
    /// @param value Native value assigned to the command; must be zero.
    /// @return output Empty output state.
    /// @return transactions Empty transaction stream.
    function executeCreditAccount(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory, bytes memory) {
        if (value != 0) revert ValueNotAllowed();
        if (input.length != 0) revert Executions.ZeroStride();
        if (state.length == 0) revert Blocks.EmptyRun();

        Reader memory reader = Readers.open(state);
        while (reader.more()) {
            (bytes32 asset, uint amount) = reader.unpackBalance();
            creditAccount(account, asset, amount);
        }

        return ("", "");
    }
}
