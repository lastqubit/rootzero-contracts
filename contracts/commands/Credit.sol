// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Specs} from "./Base.sol";
import {CreditAccountHook} from "../core/Settlement.sol";
import {Blocks, Memory} from "../codec/Blocks.sol";
import {Sizes} from "../codec/Specs.sol";
import {UnexpectedInput} from "../utils/Errors.sol";

using Executions for Execution;

/// @title CreditAccount
/// @notice Command that delivers BALANCE state blocks to an account via a virtual hook.
/// Use for internally recording credits that have already been posted externally.
abstract contract CreditAccount is CommandBase, CreditAccountHook {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("creditAccount", Specs.Balance, Specs.Empty, Specs.Empty, 0);
    }

    /// @notice Return the registered CREDIT_ACCOUNT command ID.
    function creditAccountId() internal view returns (uint) {
        return id;
    }

    /// @notice Credit each BALANCE block from the command state to the command account.
    /// @param context Command context carrying the BALANCE state stream.
    /// @return Empty output state.
    /// @return Zero native budget credit.
    function creditAccount(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackBalance();
            creditAccount(exec.account, asset, amount);
        }

        return exec.close();
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
    /// @return credit Zero native budget credit.
    function executeCreditAccount(
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal returns (bytes memory, uint) {
        if (value != 0) revert ValueNotAllowed();
        if (input.length != 0) revert UnexpectedInput();
        if (state.length == 0) revert Blocks.EmptyRun();

        (uint abs, uint end) = Memory.bounds(state, Sizes.Balance);
        while (abs < end) {
            (bytes32 asset, uint amount) = Memory.unpackBalance(abs);
            creditAccount(account, asset, amount);
            unchecked {
                abs += Sizes.Balance;
            }
        }

        return ("", 0);
    }
}
