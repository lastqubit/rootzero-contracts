// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {
    rawCall,
    rawCallCopy,
    rawQuery,
    tryRawCall,
    tryRawCallCopy
} from "../core/Calls.sol";
import {Pipeline} from "../core/Pipeline.sol";
import {Nodes} from "../utils/Nodes.sol";

contract TestCommandCalls is Pipeline {
    error TargetFailure(uint value);
    event BytesCalled(bytes data, uint value);

    function testPipe(
        bytes32 account,
        bytes memory state,
        bytes calldata steps
    ) external payable returns (uint remaining) {
        return pipe(account, state, steps, msg.value);
    }

    function testTryRawCall(
        bytes4 selector,
        address target,
        uint value,
        bytes memory input
    ) external payable returns (bool) {
        return tryRawCall(selector, target, value, input);
    }

    function testTryRawCallCopy(
        bytes4 selector,
        address target,
        uint value,
        bytes calldata input
    ) external payable returns (bool) {
        return tryRawCallCopy(selector, target, value, input);
    }

    function testRawCall(
        bytes4 selector,
        address target,
        uint value,
        bytes memory input,
        bool expectEmpty
    ) external payable returns (bytes memory) {
        return rawCall(selector, target, value, input, expectEmpty);
    }

    function testRawCallCopy(
        bytes4 selector,
        address target,
        uint value,
        bytes calldata input,
        bool expectEmpty
    ) external payable returns (bytes memory) {
        return rawCallCopy(selector, target, value, input, expectEmpty);
    }

    function testRawQuery(
        bytes4 selector,
        address target,
        bytes memory input
    ) external view returns (bytes memory) {
        return rawQuery(selector, target, input);
    }

    function noArgs() external pure returns (uint) {
        return 42;
    }

    function echoBytes(bytes calldata data) external payable returns (bytes memory) {
        emit BytesCalled(data, msg.value);
        return data;
    }

    function queryBytes(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }

    function failBytes(bytes calldata data) external pure {
        revert TargetFailure(data.length);
    }

    function command(bytes calldata context) external payable returns (bytes memory, uint) {
        return ("", uint(keccak256(context)) ^ msg.value);
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

    function enforceCommand(uint cmd) internal pure override returns (bytes4 selector, address target) {
        uint node = Nodes.command(cmd);
        selector = bytes4(uint32(node >> 160));
        target = address(uint160(node));
    }

    function execute(
        uint,
        bytes32,
        bytes memory state,
        bytes calldata,
        uint
    ) internal pure override returns (bool, bytes memory, uint) {
        return (false, state, 0);
    }
}
