// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Head} from "../Utils/Head.sol";
import {Bytes} from "../Utils/Bytes.sol";
import {slice4} from "./Data.sol";

bytes32 constant MASK4 = 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000;

// Find step addr if already pushed to input...
// @dev param selector = bytes4(keccak256(bytes(paramAbi)))

// eid:value:req:factor
// head 2 bytes plus 2 bytes req.length ??

// @dev if step has params, request must be first even when empty.

function encodeStep() {}

function toCall(bytes4 selector, uint account, bytes calldata step) pure returns (bytes memory c) {
    assembly {
        let s := step.length
        c := mload(0x40)
        mstore(0x40, add(c, add(s, 0x84)))
        mstore(c, add(s, 0x44))
        mstore(add(c, 0x20), selector)
        mstore(add(c, 0x24), account)
        mstore(add(c, 0x44), 0x40)
        calldatacopy(add(c, 0x64), sub(step.offset, 0x20), add(s, 0x20))
    }
}

function toCall(bytes4 selector, bytes memory body, bytes calldata step) pure returns (bytes memory c) {
    assembly {
        let s := step.length
        let b := mload(body)
        c := mload(0x40)
        mstore(0x40, add(add(c, b), add(s, 0x44)))
        mstore(c, add(add(b, s), 4))
        mstore(add(c, 0x20), selector)
        mcopy(add(c, 0x24), add(body, 0x20), sub(b, 0x20))
        calldatacopy(add(c, add(b, 4)), sub(step.offset, 0x20), add(s, 0x20))
    }
}

library Step {
    function toKey(string memory p) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(p)));
    }

    /*     function selector(bytes calldata step) internal pure returns (bytes4) {
        return 0; /////
    } */

    /*     function getEid(
        bytes calldata step,
        uint head
    ) internal pure returns (uint) {
        return uint(bytes32(step));
    } */

    function getEid(bytes calldata step) internal pure returns (uint) {
        return uint(bytes32(step));
    }

    function value(bytes calldata step) internal pure returns (uint) {
        return 0; /////
    }

    // remove ??
    function addr(bytes calldata step) internal pure returns (address) {
        return address(bytes20(step[12:32]));
    }

    // @dev find key and return data given step is blocks(bytes4 len, bytes4 key, bytes data).
    // blocks starts at offset 64. param(step, 0, 64) -> request param.
    function param(bytes calldata step, bytes4 key, uint offset) internal pure returns (bytes calldata) {
        assembly {
            let stepLen := step.length
            let stepOffset := step.offset
            for {

            } lt(offset, stepLen) {

            } {
                if or(gt(add(offset, 8), stepLen), iszero(calldataload(add(stepOffset, offset)))) {
                    return(0, 0)
                }

                let blockLen := shr(224, calldataload(add(stepOffset, offset)))
                if gt(add(offset, blockLen), stepLen) {
                    return(0, 0)
                }

                if or(iszero(key), eq(and(calldataload(add(stepOffset, add(offset, 4))), MASK4), key)) {
                    let dataOffset := add(stepOffset, add(offset, 8))
                    let dataLen := sub(blockLen, 8)
                    mstore(0x40, add(dataOffset, dataLen))
                    return(dataOffset, dataLen)
                }

                offset := add(offset, blockLen)
            }
            return(0, 0)
        }
    }

    // @dev expects body to be encoded params with the last being an placeholder(empty bytes array).
    function inject(bytes calldata step, bytes memory body) internal pure returns (bytes memory result) {
        assembly {
            let bodyLen := mload(body)
            if or(lt(bodyLen, 32), mload(add(body, bodyLen))) {
                mstore(0x40, add(result, 32))
                return(result, 0)
            }

            result := mload(0x40)
            let stepLen := step.length
            let dataLen := sub(bodyLen, 32)

            mstore(result, add(bodyLen, stepLen))
            mcopy(add(result, 32), add(body, 32), dataLen)
            mstore(add(add(result, 32), dataLen), stepLen)
            calldatacopy(add(add(result, 64), dataLen), step.offset, stepLen)
            mstore(0x40, add(add(result, 32), add(bodyLen, stepLen)))
        }
    }

    function injectUnchecked(bytes calldata step, bytes memory body) internal pure returns (bytes memory result) {
        assembly {
            let s := step.length
            let b := mload(body)
            result := mload(0x40)
            mstore(0x40, add(add(result, b), add(s, 0x40)))
            mstore(result, add(b, s))
            mcopy(add(result, 0x20), add(body, 0x20), sub(b, 0x20))
            calldatacopy(add(result, b), sub(step.offset, 0x20), add(s, 0x20))
        }
    }
}
