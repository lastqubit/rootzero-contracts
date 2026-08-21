// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandCalls} from "../core/Calls.sol";

contract TestCommandCalls is CommandCalls {
    function ensureTrusted(uint node) internal pure override returns (uint) {
        return node;
    }

    function testEncodeCommandCall(
        bytes4 selector,
        bytes32 account,
        bytes memory state,
        bytes calldata input
    ) external pure returns (bytes memory) {
        return encodeCommandCall(selector, account, state, input);
    }
}
