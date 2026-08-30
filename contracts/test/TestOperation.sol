// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../codec/Specs.sol";
import {Descriptors} from "../codec/Descriptors.sol";
import { NodeCalls } from "../core/Calls.sol";
import { CommanderAccess, NodeAccess } from "../core/Access.sol";

using Descriptors for uint;

contract TestOperation is NodeCalls, NodeAccess {
    constructor() CommanderAccess(0) {}

    function testCheckCursorRatio(
        bytes calldata state,
        uint stateStride,
        bytes calldata input,
        uint inputStride
    ) external pure returns (bool) {
        uint descriptor = Descriptors.create(
            Specs.group(Specs.Balance, uint8(stateStride)),
            Specs.group(Specs.Amount, uint8(inputStride)),
            Specs.Empty,
            0
        );
        descriptor.open(state, input);
        return true;
    }
}
