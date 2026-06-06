// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors } from "../Cursors.sol";
import { NodeCalls } from "../core/Calls.sol";
import { AccessControl } from "../core/Access.sol";

contract TestOperation is NodeCalls {
    constructor() AccessControl(address(0)) {}

    function testCheckCursorRatio(
        bytes calldata state,
        uint stateGroup,
        bytes calldata request,
        uint requestGroup
    ) external pure returns (bool) {
        (, uint stateGroups, ) = Cursors.init(state, 0, stateGroup);
        (, uint requestGroups, ) = Cursors.init(request, 0, requestGroup);
        if (stateGroups != requestGroups) revert Cursors.BadRatio();
        return true;
    }
}
