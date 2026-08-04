// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors, Decoders } from "../Codec.sol";
import { NodeCalls } from "../core/Calls.sol";
import { AccessControl } from "../core/Access.sol";

contract TestOperation is NodeCalls {
    constructor() AccessControl(address(0)) {}

    function testCheckCursorRatio(
        bytes calldata state,
        uint stateStride,
        bytes calldata input,
        uint inputStride
    ) external pure returns (bool) {
        Cur memory stateCursor = Decoders.open(state, stateStride);
        Cur memory inputCursor = Decoders.open(input, inputStride);
        uint cursors = stateCursor.state | (inputCursor.state << 128);
        Cursors.reconcile(cursors, 0);
        return true;
    }
}
