// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Lanes, Specs} from "./Base.sol";
import {RepayHook} from "../core/Settlement.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Reader, Readers} from "../codec/Readers.sol";

using Executions for Execution;
using Readers for Reader;

/// @notice Hook implemented by hosts that repay liabilities using native value.
abstract contract RepayPayableHook {
    /// @notice Override to repay one liability for `account` with a shared value budget.
    /// @param account Account whose liability is being repaid.
    /// @param liability Identifier for the liability side.
    /// @param debt Quantity on the liability side.
    /// @param funds Mutable execution used only for its remaining native-value budget.
    function repay(bytes32 account, bytes32 liability, uint debt, Execution memory funds) internal virtual;
}

/// @title Repay
/// @notice Command that consumes DEBT state by repaying each liability.
abstract contract Repay is CommandBase, RepayHook, Action {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("repay", Specs.Debt, Specs.Empty, Specs.Empty, 0, 0);
        action(id, Actions.Repay);
    }

    /// @notice Return the registered REPAY command ID.
    function repayId() internal view returns (uint) {
        return id;
    }

    /// @notice Repay each liability in the DEBT state stream.
    /// @param context Command context carrying the DEBT state stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function repay(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 liability, uint debt) = exec.unpackDebt(Lanes.State);
            repay(exec.account, liability, debt);
        }

        return closeCommand(exec);
    }
}

/// @title RepayPayable
/// @notice Funded command that consumes DEBT state by repaying each liability.
abstract contract RepayPayable is CommandBase, RepayPayableHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("repayPayable", Specs.Debt, Specs.Empty, Specs.Empty, 0, Flags.Funded);
        action(id, Actions.Repay);
    }

    /// @notice Repay each liability in the DEBT state stream.
    /// @param context Command context carrying the DEBT state stream.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function repayPayable(
        bytes calldata context
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 liability, uint debt) = exec.unpackDebt(Lanes.State);
            repay(exec.account, liability, debt, exec);
        }

        return closeCommand(exec);
    }
}

/// @title RepayPosition
/// @notice Command that repays POSITION liabilities and returns their assets as BALANCE state.
abstract contract RepayPosition is CommandBase, RepayHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("repayPosition", Specs.Position, Specs.Empty, Specs.Balance, 0, 0);
        action(id, Actions.Repay);
    }

    /// @notice Repay each POSITION liability and return its asset as BALANCE state.
    /// @param context Command context carrying the POSITION state stream.
    /// @return BALANCE output state containing each released asset side.
    /// @return Empty transaction stream.
    function repayPosition(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = exec.unpackPosition(Lanes.State);
            repay(exec.account, liability, debt);
            exec.outputBalance(asset, amount);
        }

        return closeCommand(exec);
    }
}

/// @title RepayPositionPayable
/// @notice Funded command that repays POSITION liabilities and returns their assets as BALANCE state.
abstract contract RepayPositionPayable is CommandBase, RepayPayableHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command(
            "repayPositionPayable", Specs.Position, Specs.Empty, Specs.Balance, 0, Flags.Funded
        );
        action(id, Actions.Repay);
    }

    /// @notice Repay each POSITION liability and return its asset as BALANCE state.
    /// @param context Command context carrying the POSITION state stream.
    /// @return BALANCE output state containing each released asset side.
    /// @return Remaining native value as a refund transaction stream.
    function repayPositionPayable(
        bytes calldata context
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount, bytes32 liability, uint debt) = exec.unpackPosition(Lanes.State);
            repay(exec.account, liability, debt, exec);
            exec.outputBalance(asset, amount);
        }

        return closeCommand(exec);
    }
}

/// @title RepayInternal
/// @notice Extends the advertised repay command with memory-state pipeline dispatch.
/// @dev This adapter is not a separate command. It uses the command ID and repayment hook
/// inherited from `Repay` while accepting the state location used by `Pipeline`.
abstract contract RepayInternal is Repay {
    /// @notice Execute the inherited repay command from an internal pipeline.
    /// @param account Account whose liabilities are repaid.
    /// @param state DEBT block stream held in pipeline memory.
    /// @param input Empty input required by the command schema.
    /// @param value Native value assigned to the command; must be zero.
    /// @return output Empty output state.
    /// @return transactions Empty transaction stream.
    function executeRepay(
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
            (bytes32 liability, uint debt) = reader.unpackDebt();
            repay(account, liability, debt);
        }

        return ("", "");
    }
}
