// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, CommandPayable, Keys} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Accounts} from "../utils/Accounts.sol";
import {Budget, Values} from "../utils/Value.sol";

using Cursors for Cur;

string constant NAME = "pipePayable";

abstract contract PipePayableHook {
    function dispatchStep(
        uint target,
        bytes32 account,
        bytes memory state,
        bytes calldata request,
        uint value
    ) internal virtual returns (bytes memory);
}

/// @title PipePayable
/// @notice Command that sequences multiple sub-command STEP invocations in a single transaction.
/// Each STEP block carries a target node, native value to forward, and an embedded request.
/// State threads through the steps: each step's output becomes the next step's state.
/// Admin accounts are not permitted to use `pipePayable`.
abstract contract PipePayable is CommandPayable, PipePayableHook {
    uint internal immutable pipePayableId = commandId(NAME);

    constructor() {
        emit Command(host, pipePayableId, NAME, Schemas.Step, Keys.Empty, Keys.Empty, true);
    }

    function pipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps,
        Budget memory budget
    ) internal returns (bytes memory) {
        (Cur memory input, , ) = cursor(steps, 1);

        while (input.i < input.bound) {
            (uint target, uint value, bytes calldata request) = input.unpackStep();
            uint spend = Values.use(budget, value);
            state = dispatchStep(target, account, state, request, spend);
        }

        settleValue(account, budget);
        input.complete();
        return state;
    }

    /// @notice Execute the pipePayable command.
    function pipePayable(
        CommandContext calldata c
    ) external payable onlyCommand(c.account) returns (bytes memory) {
        if (Accounts.isAdmin(c.account)) revert Accounts.InvalidAccount();
        Budget memory budget = Values.fromMsg();
        return pipe(c.account, c.state, c.request, budget);
    }
}
