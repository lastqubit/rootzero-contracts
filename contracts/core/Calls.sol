// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @dev Thrown when a low-level call or query fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @notice Call `addr` with `selector(input)` and report whether it succeeded.
/// @dev Encodes memory `input` as the sole `bytes` argument and ignores returndata.
/// The caller is responsible for authorization and selector/target validation.
/// @param selector Selector of a function taking one `bytes` argument.
/// @param addr Target contract address.
/// @param value Native value to forward in wei.
/// @param input Raw contents of the function's `bytes` argument.
/// @return success True when the low-level call succeeded.
function tryRawCall(
    bytes4 selector,
    address addr,
    uint value,
    bytes memory input
) returns (bool success) {
    assembly ("memory-safe") {
        let data := mload(0x40)
        let len := mload(input)
        let body := add(data, 0x44)
        mstore(data, selector)
        mstore(add(data, 0x04), 0x20)
        mstore(add(data, 0x24), len)
        mcopy(body, add(input, 0x20), len)
        mstore(add(body, len), 0)
        success := call(gas(), addr, value, data, add(0x44, and(add(len, 0x1f), not(0x1f))), 0, 0)
    }
}

/// @notice Call `addr` with `selector(input)` copied from calldata and report success.
/// @dev Encodes calldata `input` as the sole `bytes` argument without an intermediate
/// memory copy and ignores returndata. The caller is responsible for authorization
/// and selector/target validation.
/// @param selector Selector of a function taking one `bytes` argument.
/// @param addr Target contract address.
/// @param value Native value to forward in wei.
/// @param input Raw contents of the function's `bytes` argument.
/// @return success True when the low-level call succeeded.
function tryRawCallCopy(
    bytes4 selector,
    address addr,
    uint value,
    bytes calldata input
) returns (bool success) {
    assembly ("memory-safe") {
        let data := mload(0x40)
        let len := input.length
        let body := add(data, 0x44)

        mstore(data, selector)
        mstore(add(data, 0x04), 0x20)
        mstore(add(data, 0x24), len)
        calldatacopy(body, input.offset, len)
        mstore(add(body, len), 0)

        let padded := and(add(len, 0x1f), not(0x1f))
        success := call(gas(), addr, value, data, add(0x44, padded), 0, 0)
    }
}

/// @notice Call `addr` with `selector(input)` and return its decoded `bytes` result.
/// @dev Encodes memory `input` as the sole `bytes` argument, reverts with `FailedCall`
/// on call failure, and rejects invalid successful `bytes` returndata. The caller
/// is responsible for authorization and selector/target validation.
/// @param selector Selector of a `bytes -> bytes` function.
/// @param addr Target contract address.
/// @param value Native value to forward in wei.
/// @param input Raw contents of the function's `bytes` argument.
/// @param expectEmpty Whether the decoded result must be empty.
/// @return out Decoded `bytes` returned by the target.
function rawCall(
    bytes4 selector,
    address addr,
    uint value,
    bytes memory input,
    bool expectEmpty
) returns (bytes memory out) {
    bool success;
    assembly ("memory-safe") {
        let data := mload(0x40)
        let len := mload(input)
        let body := add(data, 0x44)
        mstore(data, selector)
        mstore(add(data, 0x04), 0x20)
        mstore(add(data, 0x24), len)
        mcopy(body, add(input, 0x20), len)
        mstore(add(body, len), 0)
        success := call(gas(), addr, value, data, add(0x44, and(add(len, 0x1f), not(0x1f))), 0, 0)

        let size := returndatasize()
        out := data
        mstore(out, size)
        returndatacopy(add(out, 0x20), 0, size)
        mstore(add(add(out, 0x20), size), 0)
        mstore(0x40, and(add(add(add(out, 0x20), size), 0x1f), not(0x1f)))

        if success {
            let encoded := add(data, 0x20)
            if or(lt(size, 0x40), iszero(eq(mload(encoded), 0x20))) {
                revert(0, 0)
            }
            let outputLen := mload(add(encoded, 0x20))
            if and(expectEmpty, outputLen) {
                revert(0, 0)
            }
            let padded := and(add(outputLen, 0x1f), not(0x1f))
            if or(gt(outputLen, sub(size, 0x40)), iszero(eq(size, add(0x40, padded)))) {
                revert(0, 0)
            }
            out := add(encoded, 0x20)
        }
    }
    if (!success) revert FailedCall(addr, selector, out);
}

/// @notice Call `addr` with `selector(input)` copied from calldata and return decoded bytes.
/// @dev Encodes calldata `input` as the sole `bytes` argument without an intermediate
/// memory copy, reverts with `FailedCall` on call failure, and rejects invalid
/// successful `bytes` returndata. The caller is responsible for authorization and
/// selector/target validation.
/// @param selector Selector of a `bytes -> bytes` function.
/// @param addr Target contract address.
/// @param value Native value to forward in wei.
/// @param input Raw contents of the function's `bytes` argument.
/// @param expectEmpty Whether the decoded result must be empty.
/// @return out Decoded `bytes` returned by the target.
function rawCallCopy(
    bytes4 selector,
    address addr,
    uint value,
    bytes calldata input,
    bool expectEmpty
) returns (bytes memory out) {
    bool success;
    assembly ("memory-safe") {
        let data := mload(0x40)
        let len := input.length
        let body := add(data, 0x44)
        mstore(data, selector)
        mstore(add(data, 0x04), 0x20)
        mstore(add(data, 0x24), len)
        calldatacopy(body, input.offset, len)
        mstore(add(body, len), 0)
        success := call(gas(), addr, value, data, add(0x44, and(add(len, 0x1f), not(0x1f))), 0, 0)

        let size := returndatasize()
        out := data
        mstore(out, size)
        returndatacopy(add(out, 0x20), 0, size)
        mstore(add(add(out, 0x20), size), 0)
        mstore(0x40, and(add(add(add(out, 0x20), size), 0x1f), not(0x1f)))

        if success {
            let encoded := add(data, 0x20)
            if or(lt(size, 0x40), iszero(eq(mload(encoded), 0x20))) {
                revert(0, 0)
            }
            let outputLen := mload(add(encoded, 0x20))
            if and(expectEmpty, outputLen) {
                revert(0, 0)
            }
            let padded := and(add(outputLen, 0x1f), not(0x1f))
            if or(gt(outputLen, sub(size, 0x40)), iszero(eq(size, add(0x40, padded)))) {
                revert(0, 0)
            }
            out := add(encoded, 0x20)
        }
    }
    if (!success) revert FailedCall(addr, selector, out);
}

/// @notice Query `addr` with `selector(input)` and return its decoded `bytes` result.
/// @dev Encodes memory `input` as the sole `bytes` argument, reverts with `FailedCall`
/// on query failure, and rejects invalid successful `bytes` returndata. The caller
/// is responsible for authorization and selector/target validation.
/// @param selector Selector of a `bytes -> bytes` function.
/// @param addr Target contract address.
/// @param input Raw contents of the function's `bytes` argument.
/// @return out Decoded `bytes` returned by the target.
function rawQuery(
    bytes4 selector,
    address addr,
    bytes memory input
) view returns (bytes memory out) {
    bool success;
    assembly ("memory-safe") {
        let data := mload(0x40)
        let len := mload(input)
        let body := add(data, 0x44)
        mstore(data, selector)
        mstore(add(data, 0x04), 0x20)
        mstore(add(data, 0x24), len)
        mcopy(body, add(input, 0x20), len)
        mstore(add(body, len), 0)
        success := staticcall(gas(), addr, data, add(0x44, and(add(len, 0x1f), not(0x1f))), 0, 0)

        let size := returndatasize()
        out := data
        mstore(out, size)
        returndatacopy(add(out, 0x20), 0, size)
        mstore(add(add(out, 0x20), size), 0)
        mstore(0x40, and(add(add(add(out, 0x20), size), 0x1f), not(0x1f)))

        if success {
            let encoded := add(data, 0x20)
            if or(lt(size, 0x40), iszero(eq(mload(encoded), 0x20))) {
                revert(0, 0)
            }
            let outputLen := mload(add(encoded, 0x20))
            let padded := and(add(outputLen, 0x1f), not(0x1f))
            if or(gt(outputLen, sub(size, 0x40)), iszero(eq(size, add(0x40, padded)))) {
                revert(0, 0)
            }
            out := add(encoded, 0x20)
        }
    }
    if (!success) revert FailedCall(addr, selector, out);
}
