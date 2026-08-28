// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {rawCommandCall} from "../core/Calls.sol";

contract TestCommandCalls {
    error TargetFailure(uint value);

    function testRawCommandCall(
        bytes4 selector,
        address target,
        uint value,
        bytes32 account,
        bytes memory state,
        bytes calldata input
    ) external payable returns (bytes memory output, uint credit) {
        return rawCommandCall(selector, target, value, account, state, input);
    }

    function command(bytes calldata context) external payable returns (bytes memory, uint) {
        return (context, msg.value + 7);
    }

    function failing(bytes calldata) external pure returns (bytes memory, uint) {
        revert TargetFailure(7);
    }

    function malformed(bytes calldata) external pure returns (bytes memory, uint) {
        assembly ("memory-safe") {
            mstore(0, 0x20)
            mstore(0x20, 0)
            mstore(0x40, 0)
            return(0, 0x60)
        }
    }

    function shortReturn(bytes calldata) external pure returns (bytes memory, uint) {
        assembly ("memory-safe") {
            return(0, 0x40)
        }
    }

    function oversizedLength(bytes calldata) external pure returns (bytes memory, uint) {
        assembly ("memory-safe") {
            mstore(0, 0x40)
            mstore(0x20, 0)
            mstore(0x40, 0x20)
            return(0, 0x60)
        }
    }

    function trailingData(bytes calldata) external pure returns (bytes memory, uint) {
        assembly ("memory-safe") {
            mstore(0, 0x40)
            mstore(0x20, 0)
            mstore(0x40, 0)
            mstore(0x60, 0)
            return(0, 0x80)
        }
    }
}
