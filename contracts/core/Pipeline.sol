// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {TrustAccess} from "./Access.sol";
import {rawCommandCall} from "./Calls.sol";
import {Cursors} from "../utils/Cursors.sol";
import {InsufficientValue, OutOfBounds, UnexpectedState} from "../utils/Errors.sol";
import {unpackCommand} from "../utils/Nodes.sol";

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

/// @notice Hook implemented by pipeline hosts that execute host-local commands.
abstract contract ExecuteHook {
    /// @notice Try to execute one command whose node ID targets the current host.
    /// @dev Implementations returning `handled = true` are responsible for
    /// authorizing the command. Return false without side effects to delegate to
    /// the trusted normal external entrypoint. Implementations may revert instead.
    function execute(
        uint cmd,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint value
    ) internal virtual returns (bool handled, bytes memory output, uint credit);
}

/// @title Pipeline
/// @notice Core pipeline functionality shared by higher-level surfaces.
abstract contract Pipeline is TrustAccess, PipeHook, ExecuteHook {
    function run(
        uint cmd,
        bytes32 account,
        bytes memory state,
        bytes calldata input,
        uint value
    ) private returns (bytes memory output, uint credit) {
        (bytes4 selector, address target) = unpackCommand(cmd);
        if (target == address(this)) {
            bool handled;
            (handled, output, credit) = execute(cmd, account, state, input, value);
            if (handled) return (output, credit);
        }
        ensureTrusted(cmd);
        return rawCommandCall(selector, target, value, account, state, input);
    }

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
            (uint cmd, uint value, bytes calldata input, uint next) = Blocks.unpackStep(abs);
            if (next > end) revert OutOfBounds();
            if (value > budget) revert InsufficientValue();
            unchecked {
                budget -= value;
            }
            (state, value) = run(cmd, account, state, input, value);
            budget += value;
            abs = next;
        }

        if (state.length != 0) revert UnexpectedState();
        return budget;
    }
}
