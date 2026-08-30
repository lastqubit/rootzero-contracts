// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {rawCall, rawQuery, tryRawCall} from "../core/Calls.sol";
import {Pipeline} from "../core/Pipeline.sol";

contract TestCommandCalls is Pipeline {
    error TargetFailure(uint value);

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
        bytes memory args
    ) external payable returns (bool) {
        return tryRawCall(selector, target, value, args);
    }

    function testRawCall(
        bytes4 selector,
        address target,
        uint value,
        bytes memory args
    ) external payable returns (bytes memory) {
        return rawCall(selector, target, value, args);
    }

    function testRawQuery(
        bytes4 selector,
        address target,
        bytes memory args
    ) external view returns (bytes memory) {
        return rawQuery(selector, target, args);
    }

    function echo(uint amount, bytes calldata data) external payable returns (uint, bytes memory, uint) {
        return (amount, data, msg.value);
    }

    function query(uint amount, bytes calldata data) external view returns (uint, bytes memory, address) {
        return (amount, data, msg.sender);
    }

    function noArgs() external pure returns (uint) {
        return 42;
    }

    function fail(uint value) external pure {
        revert TargetFailure(value);
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

    function ensureTrusted(uint node) internal pure override returns (uint) {
        return node;
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
