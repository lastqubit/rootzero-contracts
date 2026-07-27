// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Decoders, Cur, Readers, Reader} from "../Cursors.sol";
import {Settlement} from "./Settlement.sol";
import {Execution, Executions} from "../execution/Execution.sol";

using Decoders for Cur;
using Readers for Reader;
using Executions for Execution;

/// @title Pipeline
/// @notice Core pipeline functionality shared by higher-level surfaces.
abstract contract Pipeline is Settlement {
    /// @dev Thrown when the pipeline finishes with non-empty threaded state.
    error UnexpectedState();

    /// @notice Override to dispatch one piped step.
    /// Called once per STEP block. The returned state becomes the state passed to
    /// the next step, and the final returned state must be empty. Returned
    /// transactions are decoded and passed individually to `settle` before the next step runs.
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
    /// Callers remain responsible for settling any unspent value in `exec`.
    /// @param account Account identifier used for each dispatched step.
    /// @param state Initial state block stream passed to the first step.
    /// @param steps STEP block stream to execute.
    /// @param exec Mutable execution shared across all steps.
    function pipe(bytes32 account, bytes memory state, bytes calldata steps, Execution memory exec) internal {
        (Cur memory input, ) = Decoders.init(steps, 1, 0);

        while (input.more()) {
            (uint target, uint resources, bytes calldata request) = input.unpackStep();
            Reader memory txs;
            (state, txs.source) = dispatch(target, account, state, request, exec.useValue(resources));
            while (txs.more()) {
                (bytes32 from, bytes32 to, bytes32 asset, uint amount) = txs.unpackTransaction();
                settle(from, to, asset, amount);
            }
        }

        if (state.length != 0) revert UnexpectedState();
    }
}
