// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {STEP, STEP_KEY} from "../blocks/Schema.sol";
import {Data, DataRef} from "../Blocks.sol";
import {isAdminAccount, InvalidAccount} from "../utils/Accounts.sol";
import {msgValue, useValue, ValueBudget} from "../utils/Value.sol";

using Data for DataRef;

string constant NAME = "pipe";

abstract contract Pipe is CommandBase {
    uint internal immutable pipeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, STEP, pipeId, 0, 0);
    }

    /// @dev Override to execute a single STEP target and return the next
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
        ValueBudget memory budget
    ) internal returns (bytes memory) {
        uint i = 0;
        while (i < steps.length) {
            DataRef memory ref = Data.from(steps, i);
            if (ref.key != STEP_KEY) break;
            (uint target, uint value, bytes calldata request) = ref.unpackStep();
            uint spend = useValue(value, budget);
            state = dispatchStep(target, account, state, request, spend);
            i = ref.cursor;
        }

        return done(state, 0, i);
    }

    // Any unused value will not be credited back to the account using this path.
    function pipe(CommandContext calldata c) external payable onlyCommand(pipeId, c.target) returns (bytes memory) {
        if (isAdminAccount(c.account)) revert InvalidAccount();
        ValueBudget memory budget = msgValue();
        return pipe(c.account, c.state, c.request, budget);
    }
}
