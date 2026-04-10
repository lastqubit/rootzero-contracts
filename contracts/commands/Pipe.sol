// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
import { Accounts } from "../utils/Accounts.sol";
import { Values } from "../utils/Value.sol";

using Cursors for Cur;

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
        (Cur memory request, ) = cursor(steps, 1);

        while (request.i < request.bound) {
            (uint target, uint value, bytes calldata stepRequest) = request.unpackStep();
            uint spend = Values.use(budget, value);
            state = dispatchStep(target, account, state, stepRequest, spend);
        }

        request.complete();
        return state;
    }

    // Any unused value will not be credited back to the account using this path.
    function pipe(CommandContext calldata c) external payable onlyCommand(pipeId, c.target) returns (bytes memory) {
        if (Accounts.isAdmin(c.account)) revert Accounts.InvalidAccount();
        Values.Budget memory budget = Values.fromMsg();
        return pipe(c.account, c.state, c.request, budget);
    }
}





