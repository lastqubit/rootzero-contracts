// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

// @dev head with any value(selector) as the last uint32 is expected to have a body encoded to work with these call functions.

error BadValue();

struct Value {
    uint amount;
}

function useValue(Value memory total, uint amount) pure returns (uint) {
    if (amount > total.amount) {
        revert BadValue();
    }
    total.amount -= amount;
    return amount;
}

library Call {
    function encodeCall(
        bytes4 selector,
        uint account,
        bytes calldata step
    ) internal pure returns (bytes memory result) {
        assembly {
            let s := step.length
            let size := add(0x84, s)

            result := mload(0x40)

            mstore(0x40, add(result, and(add(size, 0x1f), not(0x1f))))
            mstore(result, add(0x64, s))
            mstore(add(result, 0x24), account)

            let ptr := add(result, 0x20)
            mstore8(ptr, byte(0, selector))
            mstore8(add(ptr, 1), byte(1, selector))
            mstore8(add(ptr, 2), byte(2, selector))
            mstore8(add(ptr, 3), byte(3, selector))

            // Store offset to step (0x40)
            mstore(add(result, 0x44), 0x40)

            // Copy step length and data
            calldatacopy(add(result, 0x64), step.offset, add(s, 0x20))
        }
    }

    function encodeCall(
        bytes4 selector,
        bytes memory args,
        bytes calldata step
    ) internal pure returns (bytes memory result) {
        assembly {
            let s := step.length
            let argsLen := mload(args)
            let argsToCopy := sub(argsLen, 0x20)
            let size := add(add(4, argsLen), s)

            result := mload(0x40)

            mstore(0x40, add(result, and(add(add(0x20, size), 0x1f), not(0x1f))))
            mstore(result, size)

            let ptr := add(result, 0x20)
            mstore8(ptr, byte(0, selector))
            mstore8(add(ptr, 1), byte(1, selector))
            mstore8(add(ptr, 2), byte(2, selector))
            mstore8(add(ptr, 3), byte(3, selector))

            // Copy args except last 32 bytes (the zero length) using mcopy
            mcopy(add(result, 0x24), add(args, 0x20), argsToCopy)

            // Copy step length and data at the position where the zero was
            let stepPos := add(add(result, 0x24), argsToCopy)
            calldatacopy(stepPos, step.offset, add(s, 0x20))
        }
    }

    function getParam(bytes calldata step, bytes4 target, uint offset) internal pure returns (bytes calldata result) {
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

                let head := calldataload(cursor)
                let len := and(shr(192, head), 0xffffffff)

                // Calculate data boundaries
                let sod := add(cursor, 8)
                let eod := add(sod, len)

                // Check for overflow or out of bounds
                if or(lt(eod, sod), gt(eod, eos)) {
                    break
                }

                // Match found
                if or(iszero(target), eq(and(shr(224, head), 0xffffffff), target)) {
                    result.offset := sod
                    result.length := len
                    break
                }

                cursor := eod
            }
        }
    }
}
