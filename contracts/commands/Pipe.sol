// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
import { Accounts } from "../utils/Accounts.sol";
import { Values } from "../utils/Value.sol";

using Cursors for Cur;

string constant NAME = "pipe";

/// @title Pipe
/// @notice Command that sequences multiple sub-command STEP invocations in a single transaction.
/// Each STEP block carries a target node, native value to forward, and an embedded request.
/// State threads through the steps: each step's output becomes the next step's state.
/// Admin accounts are not permitted to use `pipe`.
abstract contract Pipe is CommandBase {
    uint internal immutable pipeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Step, pipeId, 0, 0);
    }

    /// @notice Override to execute a single STEP and return the resulting state.
    /// The returned state is passed as the `state` argument of the next STEP.
    /// @param target Destination command node ID from the STEP block.
    /// @param account Caller's account identifier.
    /// @param state Current threaded state from the previous step.
    /// @param request Embedded request bytes from the STEP block.
    /// @param value Native value forwarded with this step.
    /// @return Next state to thread into the following step.
    function dispatchStep(
        uint target,
        bytes32 account,
        bytes memory state,
        bytes calldata request,
        uint value
    ) internal virtual returns (bytes memory);

    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        Values.Budget memory budget
    ) internal returns (bytes memory) {
        (Cur memory input, , ) = cursor(steps, 1);

        while (input.i < input.bound) {
            (uint target, uint value, bytes calldata request) = input.unpackStep();
            uint spend = Values.use(budget, value);
            state = dispatchStep(target, account, state, request, spend);
        }

        input.complete();
        return state;
    }

    /// @notice Execute the pipe command.
    /// Note: any unused `msg.value` is NOT automatically refunded to the caller.
    function pipe(CommandContext calldata c) external payable onlyCommand(pipeId, c.target) returns (bytes memory) {
        if (Accounts.isAdmin(c.account)) revert Accounts.InvalidAccount();
        Values.Budget memory budget = Values.fromMsg();
        return pipe(c.account, c.state, c.request, budget);
    }
}





