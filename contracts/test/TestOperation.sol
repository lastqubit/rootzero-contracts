// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../codec/Specs.sol";
import {Execution, Executions} from "../execution/Execution.sol";

using Executions for Execution;

contract TestOperation {

    function testCheckCursorRatio(
        bytes calldata state,
        uint stateStride,
        bytes calldata input,
        uint inputStride
    ) external pure returns (bool) {
        uint descriptor = Executions.describe(
            Specs.group(Specs.Balance, uint8(stateStride)),
            Specs.group(Specs.Amount, uint8(inputStride)),
            Specs.Empty,
            0
        );
        Execution memory exec;
        exec.open(descriptor, 0, 0, state, input);
        return true;
    }
}
