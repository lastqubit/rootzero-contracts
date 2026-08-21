// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Lanes, Specs} from "./Base.sol";
import {RepayHook} from "../core/Settlement.sol";
import {Action} from "../annotations/Action.sol";
import {Actions} from "../utils/Actions.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that repay position liabilities using native value.
abstract contract RepayPayableHook {
    /// @notice Override to repay one liability for `account` with a shared value budget.
    /// @param account Account whose liability is being repaid.
    /// @param liability Identifier for the liability side.
    /// @param debt Quantity on the liability side.
    /// @param funds Mutable execution used only for its remaining native-value budget.
    function repay(bytes32 account, bytes32 liability, uint debt, Execution memory funds) internal virtual;
}

/// @title Repay
/// @notice Command that repays POSITION liabilities and returns their assets as BALANCE state.
abstract contract Repay is CommandBase, RepayHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("repay", Specs.Position, Specs.Empty, Specs.Balance, 0, 0);
        action(id, Actions.Settle);
    }

    /// @notice Repay each POSITION liability and return its asset as BALANCE state.
    /// @param context Command context carrying the POSITION state stream.
    /// @return BALANCE output state containing each released asset side.
    /// @return Empty transaction stream.
    function repay(
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

/// @title RepayPayable
/// @notice Funded command that repays POSITION liabilities and returns their assets as BALANCE state.
abstract contract RepayPayable is CommandBase, RepayPayableHook, Action {
    uint private immutable descriptor;

    constructor() {
        uint id;
        (id, descriptor) = command("repayPayable", Specs.Position, Specs.Empty, Specs.Balance, 0, Flags.Funded);
        action(id, Actions.Settle);
    }

    /// @notice Repay each POSITION liability and return its asset as BALANCE state.
    /// @param context Command context carrying the POSITION state stream.
    /// @return BALANCE output state containing each released asset side.
    /// @return Remaining native value as a refund transaction stream.
    function repayPayable(
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
