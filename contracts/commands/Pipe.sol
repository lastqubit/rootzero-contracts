// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "./Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../Cursors.sol";
import { Accounts } from "../utils/Accounts.sol";
import { Values } from "../utils/Value.sol";

using Cursors for Cursor;

string constant NAME = "pipe";

abstract contract Pipe is CommandBase {
    uint internal immutable pipeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Step, pipeId, 0, 0);
    }

    /// @dev Override to execute a single STEP request and return the next
    /// threaded state for the pipe.
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
        (Cursor memory stepsInput, ) = Cursors.openRun(steps, 0, Keys.Step);
        while (stepsInput.i < stepsInput.end) {
            (uint target, uint value, bytes calldata request) = stepsInput.unpackStep();
            uint spend = Values.use(budget, value);
            state = dispatchStep(target, account, state, request, spend);
        }

        stepsInput.finish();
        return state;
    }

    // Any unused value will not be credited back to the account using this path.
    function pipe(CommandContext calldata c) external payable onlyCommand(pipeId, c.target) returns (bytes memory) {
        if (Accounts.isAdmin(c.account)) revert Accounts.InvalidAccount();
        Values.Budget memory budget = Values.fromMsg();
        return pipe(c.account, c.state, c.request, budget);
    }
}




