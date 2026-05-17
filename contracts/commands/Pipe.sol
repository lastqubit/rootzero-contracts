// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Payable, Keys} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract PipePayableCore is Payable {
    error UnexpectedState();

    /// @notice Override to dispatch one piped command step.
    /// Called once per STEP block. The returned bytes become the state passed to
    /// the next step.
    /// @param id Command node ID to invoke or handle.
    /// @param account Account identifier for the piped command context.
    /// @param state Current threaded state block stream.
    /// @param request Step request block stream.
    /// @param value Native value assigned to this step.
    /// @return Updated state block stream for the next step.
    function dispatchCommand(
        uint id,
        bytes32 account,
        bytes memory state,
        bytes calldata request,
        uint value
    ) internal virtual returns (bytes memory);

    /// @notice Execute a STEP block stream as one stage of a larger pipeline.
    /// @param account Account identifier used for each dispatched step.
    /// @param state Initial state block stream passed to the first step.
    /// @param steps STEP block stream to execute.
    /// @param budget Mutable native-value budget shared across all steps.
    /// @return Final state returned by the last dispatched step, or the initial state when no steps run.
    function stage(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        Budget memory budget
    ) internal returns (bytes memory) {
        (Cur memory input, ) = Cursors.init(steps, 1);

        while (input.i < input.bound) {
            (uint target, uint value, bytes calldata request) = input.unpackStep();
            uint spend = useValue(budget, value);
            state = dispatchCommand(target, account, state, request, spend);
        }

        settleValue(account, budget);
        input.close();
        return state;
    }

    /// @notice Execute a STEP block stream and require the final threaded state to be empty.
    /// Reverts with `UnexpectedState` if the state returned after the pipe completes is non-empty.
    /// @param account Account identifier used for each dispatched step.
    /// @param state Initial state block stream passed to the first step.
    /// @param steps STEP block stream to execute.
    /// @param budget Mutable native-value budget shared across all steps.
    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        Budget memory budget
    ) internal {
        if (stage(account, state, steps, budget).length != 0) revert UnexpectedState();
    }
}

/// @title PipePayable
/// @notice Command that sequences multiple sub-command STEP invocations in a single transaction.
/// Each STEP block carries a command node, native value to forward, and an embedded request.
/// State threads through the steps: each step's output becomes the next step's state.
/// Admin accounts are not permitted to use `pipePayable`.
abstract contract PipePayable is CommandBase, PipePayableCore {
    string private constant NAME = "pipePayable";

    uint internal immutable pipePayableId = commandId(NAME);

    constructor() {
        emit Command(host, pipePayableId, NAME, "1:0:0", Schemas.Step, Keys.Empty, Keys.Empty, true);
    }

    /// @notice Execute the pipePayable command.
    function pipePayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory) {
        pipe(Accounts.ensureNotAdmin(c.account), c.state, c.request, valueBudget());
        return "";
    }
}

/// @title StagePayable
/// @notice Command that executes a STEP stream as one stage of a larger pipeline.
/// Each STEP block carries a command node, native value to forward, and an embedded request.
/// State threads through the steps and the final threaded state is returned.
/// Admin accounts are not permitted to use `stagePayable`.
abstract contract StagePayable is CommandBase, PipePayableCore {
    string private constant NAME = "stagePayable";

    uint internal immutable stagePayableId = commandId(NAME);

    constructor() {
        emit Command(host, stagePayableId, NAME, "1:0:0", Schemas.Step, Keys.Empty, Keys.Empty, true);
    }

    /// @notice Execute the stagePayable command.
    function stagePayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory) {
        return stage(Accounts.ensureNotAdmin(c.account), c.state, c.request, valueBudget());
    }
}
