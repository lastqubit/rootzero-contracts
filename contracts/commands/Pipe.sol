// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {BlockRef, STEP, STEP_KEY} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
import {isAdminAccount, InvalidAccount} from "../utils/Accounts.sol";
import {msgValue, useValue, ValueBudget} from "../utils/Value.sol";

using Blocks for BlockRef;

string constant NAME = "pipe";

abstract contract Pipe is CommandBase {
    uint internal immutable pipeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, STEP, pipeId, 0, 0);
    }

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
            BlockRef memory ref = Blocks.from(steps, i);
            if (ref.key != STEP_KEY) break;
            (uint target, uint value, bytes calldata request) = ref.unpackStep(steps);
            uint spend = useValue(value, budget);
            state = dispatchStep(target, account, state, request, spend);
            i = ref.end;
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
