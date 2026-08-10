// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../codec/Specs.sol";
import {Descriptors} from "../codec/Descriptors.sol";
import {Executions} from "../execution/Execution.sol";
import { NodeCalls } from "../core/Calls.sol";
import { CommanderAccess, NodeAccess } from "../core/Access.sol";

contract TestOperation is NodeCalls, NodeAccess {
    constructor() CommanderAccess(address(0)) {}

    function testCheckCursorRatio(
        bytes calldata state,
        uint stateStride,
        bytes calldata input,
        uint inputStride
    ) external view returns (bool) {
        uint descriptor = Descriptors.create(
            Specs.group(Specs.Balance, uint8(stateStride)),
            Specs.group(Specs.Amount, uint8(inputStride)),
            Specs.Empty,
            0,
            0
        );
        Executions.open(state, input, descriptor, 0);
        return true;
    }
}
