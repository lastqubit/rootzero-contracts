// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Bytes} from "../Utils/Bytes.sol";
import {slice4} from "./Data.sol";

bytes32 constant MASK4 = 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000;

// Find step addr if already pushed to input...
// @dev param selector = bytes4(keccak256(bytes(paramAbi)))

// eid:value:req:factor
// head 2 bytes plus 2 bytes req.length ??

// @dev if step has params, request must be first even when empty.

function encodeStep() {}

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

    // @dev find key and return data given step is blocks(uint32 len, bytes4 key, bytes data).
    function param(bytes calldata step, bytes4 target, uint offset) internal pure returns (bytes calldata result) {
        assembly {
            let start := step.offset
            let dataLen := step.length
            result.offset := 0
            result.length := 0

            for {

            } iszero(gt(add(offset, 8), dataLen)) {

            } {
                let currentPos := add(start, offset)
                let len := and(shr(224, calldataload(currentPos)), 0xffffffff)
                let key := and(shr(224, calldataload(add(currentPos, 4))), 0xffffffff)

                // Validate length and check for overflow/bounds
                let newOffset := add(offset, len)
                if or(lt(len, 8), or(lt(newOffset, offset), gt(newOffset, dataLen))) {
                    break
                }

                // Check if this is the target we're looking for
                if or(iszero(target), eq(key, target)) {
                    result.offset := add(currentPos, 8)
                    result.length := sub(len, 8)
                    break
                }

                offset := newOffset
            }
        }
    }

    /*     function encodeBlock(bytes4 key, bytes memory data) internal pure returns (bytes memory) {
        uint32 len = uint32(data.length); // Just data length, not including header
        return abi.encodePacked(key, len, data);
    } */

    function param2(bytes calldata step, bytes4 target, uint offset) internal pure returns (bytes calldata result) {
        assembly {
            let sos := step.offset
            let eos := add(sos, step.length)
            let cursor := add(sos, offset)
            result.offset := 0
            result.length := 0

            //prettier-ignore
            for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
                // Check cursor overflow and ensure room for header
                if or(lt(cursor, sos), gt(cursor, sub(eos, 8))) {
                    break
                }

                let header := calldataload(cursor)
                let len := and(shr(192, header), 0xffffffff)

                // Calculate data boundaries
                let sod := add(cursor, 8)
                let eod := add(sod, len)

                // Check for overflow or out of bounds
                if or(lt(eod, sod), gt(eod, eos)) {
                    break
                }

                // Match found
                if or(iszero(target), eq(and(shr(224, header), 0xffffffff), target)) {
                    result.offset := sod
                    result.length := len
                    break
                }

                cursor := eod
            }
        }
    }
    /*     // @dev expects body to be encoded params with the last being an placeholder(empty bytes array).
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
    } */
}
