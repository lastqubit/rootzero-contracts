// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cursors, Cur} from "../Cursors.sol";
import {Payable} from "./Payable.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title Pipeline
/// @notice Core pipeline functionality shared by higher-level surfaces.
abstract contract Pipeline is Payable {
    /// @dev Thrown when the pipeline finishes with non-empty threaded state.
    error UnexpectedState();

    /// @notice Override to handle transactions returned by a dispatched command.
    /// Called once per non-empty transaction stream before the next step runs.
    /// @param transactions Transaction block stream produced by the command.
    function settle(bytes memory transactions) internal virtual;

    /// @notice Override to dispatch one piped step.
    /// Called once per STEP block. The returned state becomes the state passed to
    /// the next step, and the final returned state must be empty. Returned
    /// transactions are passed to `settle` before the next step runs.
    /// @param target Node ID to invoke or handle.
    /// @param account Account identifier for the piped context.
    /// @param state Current threaded state block stream.
    /// @param request Step request block stream.
    /// @param value Native EVM value assigned to this step.
    /// @return nextState Updated state block stream for the next step.
    /// @return transactions Transaction block stream produced by the command.
    function dispatch(
        uint target,
        bytes32 account,
        bytes memory state,
        bytes calldata request,
        uint128 value
    ) internal virtual returns (bytes memory nextState, bytes memory transactions);

    /// @notice Execute a STEP block stream through the pipeline.
    /// @dev Reverts with `UnexpectedState` if the final threaded state is non-empty.
    /// Callers remain responsible for settling any unspent value in `budget`.
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
        (Cur memory input, ) = Cursors.init(steps, 1);

        while (input.i < input.len) {
            (uint target, uint resources, bytes calldata request) = input.unpackStep();
            bytes memory transactions;
            (state, transactions) = dispatch(target, account, state, request, useValue(budget, resources));
            if (transactions.length != 0) settle(transactions);
        }

        if (state.length != 0) revert UnexpectedState();
    }
}
