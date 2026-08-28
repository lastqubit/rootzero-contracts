// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {Cursors} from "../utils/Cursors.sol";
import {InsufficientValue, OutOfBounds, UnexpectedState} from "../utils/Errors.sol";

/// @notice Hook implemented by hosts that execute encoded step streams.
abstract contract PipeHook {
    /// @notice Execute a step stream and return its remaining native-value budget.
    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        uint budget
    ) internal virtual returns (uint remaining);
}

/// @title Pipeline
/// @notice Core pipeline functionality shared by higher-level surfaces.
abstract contract Pipeline is PipeHook {
    /// @notice Override to dispatch one piped step.
    /// Called once per STEP block. The returned state becomes the state passed to
    /// the next step, and the final returned state must be empty. Returned
    /// credit is added to the shared native-value budget before the next step runs.
    /// @param cmd Command node ID to invoke or handle.
    /// @param account Account identifier for the piped context.
    /// @param state Current threaded state block stream.
    /// @param input Step input block stream.
    /// @param value Native EVM value assigned to this step.
    /// @return output Updated state block stream for the next step.
    /// @return credit Trusted native value to add to the pipeline budget.
    function dispatch(
        uint cmd,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint128 value
    ) internal virtual returns (bytes memory output, uint credit);

    /// @notice Execute a STEP block stream through the pipeline.
    /// @dev Reverts with `UnexpectedState` if the final threaded state is non-empty.
    /// Callers remain responsible for settling the returned unspent value.
    /// @param account Account identifier used for each dispatched step.
    /// @param state Initial state block stream passed to the first step.
    /// @param steps STEP block stream to execute.
    /// @param budget Native-value budget shared across all steps.
    /// @return remaining Native value remaining after every step executes.
    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        uint budget
    ) internal virtual override returns (uint remaining) {
        (uint abs, uint end) = Cursors.bounds(steps);

        while (abs < end) {
            uint cmd;
            uint128 value;
            bytes calldata input;
            (cmd, value, input, abs) = Blocks.unpackStep(abs);
            if (abs > end) revert OutOfBounds();
            if (value > budget) revert InsufficientValue();
            unchecked {
                budget -= value;
            }
            uint credit;
            (state, credit) = dispatch(cmd, account, state, input, value);
            budget += credit;
        }

        if (state.length != 0) revert UnexpectedState();
        return budget;
    }
}
