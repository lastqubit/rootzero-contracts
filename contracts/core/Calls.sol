// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {TrustAccess} from "./Access.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @notice Try a raw low-level call to another node and return whether it succeeded.
/// @param node Node ID of the callee.
/// @param value Native value to forward in wei.
/// @param data Complete encoded calldata to send.
/// @return success True if the low-level call succeeded.
function tryRawCall(uint node, uint value, bytes memory data) returns (bool success) {
    address addr = Nodes.addr(node);
    (success, ) = payable(addr).call{value: value}(data);
}

/// @notice Try a raw low-level call using a separate selector and ABI-encoded arguments.
/// @dev `args` must not include the selector. The byte-array length is temporarily
/// used as scratch space so the call does not allocate or copy `selector || args`.
function tryRawCall(
    bytes4 selector,
    address addr,
    uint value,
    bytes memory args
) returns (bool success) {
    assembly ("memory-safe") {
        let len := mload(args)
        mstore(args, or(and(len, not(0xffffffff)), shr(224, selector)))
        success := call(gas(), addr, value, add(args, 0x1c), add(len, 0x04), 0, 0)
        mstore(args, len)
    }
}

/// @notice Make a raw low-level call to another node and revert when it fails.
/// @param node Node ID of the callee.
/// @param value Native value to forward in wei.
/// @param data Complete encoded calldata to send.
/// @return out Return data from the successful call.
function rawCall(uint node, uint value, bytes memory data) returns (bytes memory out) {
    bool success;
    address addr = Nodes.addr(node);
    (success, out) = payable(addr).call{value: value}(data);
    if (!success) revert FailedCall(addr, bytes4(data), out);
}

/// @notice Make a raw low-level call using a separate selector and ABI-encoded arguments.
/// @dev `args` must not include the selector. The byte-array length is temporarily
/// used as scratch space so the call does not allocate or copy `selector || args`.
function rawCall(
    bytes4 selector,
    address addr,
    uint value,
    bytes memory args
) returns (bytes memory out) {
    bool success;
    assembly ("memory-safe") {
        let len := mload(args)
        mstore(args, or(and(len, not(0xffffffff)), shr(224, selector)))
        success := call(gas(), addr, value, add(args, 0x1c), add(len, 0x04), 0, 0)
        mstore(args, len)

        let size := returndatasize()
        out := mload(0x40)
        mstore(out, size)
        returndatacopy(add(out, 0x20), 0, size)
        mstore(add(add(out, 0x20), size), 0)
        mstore(0x40, and(add(add(add(out, 0x20), size), 0x1f), not(0x1f)))
    }
    if (!success) revert FailedCall(addr, selector, out);
}

/// @notice Make a raw low-level read-only query to another node and revert when it fails.
/// @param node Node ID of the callee.
/// @param data Complete encoded calldata to send.
/// @return out Return data from the successful query.
function rawQuery(uint node, bytes memory data) view returns (bytes memory out) {
    bool success;
    address addr = Nodes.addr(node);
    (success, out) = addr.staticcall(data);
    if (!success) revert FailedCall(addr, bytes4(data), out);
}

/// @notice Make a raw read-only query using a separate selector and ABI-encoded arguments.
/// @dev `args` must not include the selector. The byte-array length is temporarily
/// used as scratch space so the call does not allocate or copy `selector || args`.
function rawQuery(
    bytes4 selector,
    address addr,
    bytes memory args
) view returns (bytes memory out) {
    bool success;
    assembly ("memory-safe") {
        let len := mload(args)
        mstore(args, or(and(len, not(0xffffffff)), shr(224, selector)))
        success := staticcall(gas(), addr, add(args, 0x1c), add(len, 0x04), 0, 0)
        mstore(args, len)

        let size := returndatasize()
        out := mload(0x40)
        mstore(out, size)
        returndatacopy(add(out, 0x20), 0, size)
        mstore(add(add(out, 0x20), size), 0)
        mstore(0x40, and(add(add(add(out, 0x20), size), 0x1f), not(0x1f)))
    }
    if (!success) revert FailedCall(addr, selector, out);
}

/// @title NodeCalls
/// @notice Trusted low-level inter-node calls backed by a host-provided node policy.
abstract contract NodeCalls is TrustAccess {
    /// @notice Try a trusted low-level call to another node and return whether it succeeded.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return success True if the low-level call succeeded.
    function tryTrustedCall(uint node, uint value, bytes memory data) internal returns (bool success) {
        return tryRawCall(ensureTrusted(node), value, data);
    }

    /// @notice Make a trusted low-level call to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function trustedCall(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        return rawCall(ensureTrusted(node), value, data);
    }

    /// @notice Make a trusted low-level read-only query to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful query.
    function trustedQuery(uint node, bytes memory data) internal view returns (bytes memory out) {
        return rawQuery(ensureTrusted(node), data);
    }
}

/// @title PortCalls
/// @notice Trusted port-call helpers for contracts that route port nodes.
abstract contract PortCalls is NodeCalls {
    /// @notice Try to encode and call a trusted port node.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return success True if the low-level port call succeeded.
    function tryCallPort(uint port, uint value, bytes memory input) internal returns (bool success) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return tryTrustedCall(port, value, data);
    }

    /// @notice Try to encode and call a trusted port node by copying input from calldata.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return success True if the low-level port call succeeded.
    function tryCallPortCopy(uint port, uint value, bytes calldata input) internal returns (bool success) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return tryTrustedCall(port, value, data);
    }

    /// @notice Encode and call a trusted port node.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return Decoded port output block stream.
    function callPort(uint port, uint value, bytes memory input) internal returns (bytes memory) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return abi.decode(trustedCall(port, value, data), (bytes));
    }

    /// @notice Encode and call a trusted port node by copying input from calldata.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return Decoded port output block stream.
    function callPortCopy(uint port, uint value, bytes calldata input) internal returns (bytes memory) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return abi.decode(trustedCall(port, value, data), (bytes));
    }
}
