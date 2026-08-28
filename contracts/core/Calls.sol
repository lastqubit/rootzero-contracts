// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {TrustAccess} from "./Access.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @notice Execute a raw `command(bytes)` call and decode its state and credit results.
/// @dev The caller must validate and authorize the command before entering this helper.
/// Uses one scratch region for both call data and return data. Successful return data
/// must use the exact ABI layout of `(bytes, uint)`.
function rawCommandCall(
    bytes4 selector,
    address target,
    uint value,
    bytes32 account,
    bytes memory state,
    bytes calldata input
) returns (bytes memory output, uint credit) {
    assembly ("memory-safe") {
        let scratch := mload(0x40)
        let statelen := mload(state)
        let ctxlen := add(56, add(statelen, input.length))

        // ABI envelope for command(bytes).
        mstore(scratch, selector)
        mstore(add(scratch, 0x04), 0x20)
        mstore(add(scratch, 0x24), ctxlen)

        // CONTEXT(account, BYTES(state), BYTES(input)).
        let ctx := add(scratch, 0x44)
        // 0xc5769e23 = bytes4(keccak256("#context"))
        mstore(ctx, or(shl(224, 0xc5769e23), shl(192, sub(ctxlen, 8))))
        // `ctxlen` is dead after the header and can carry the complete call length.
        ctxlen := add(68, and(add(ctxlen, 0x1f), not(0x1f)))
        mstore(add(ctx, 0x08), account)
        let stateblk := add(ctx, 0x28)
        // 0x6911b332 = bytes4(keccak256("#bytes"))
        mstore(stateblk, or(shl(224, 0x6911b332), shl(192, statelen)))
        mcopy(add(stateblk, 0x08), add(state, 0x20), statelen)
        let inputblk := add(add(stateblk, 0x08), statelen)
        let inputlen := input.length
        mstore(inputblk, or(shl(224, 0x6911b332), shl(192, inputlen)))
        calldatacopy(add(inputblk, 0x08), input.offset, inputlen)

        // ABI word alignment also covers the input header's full-word write. Advance
        // the free memory pointer once, after the return-data size is also known.
        let inputend := and(add(add(scratch, ctxlen), 0x1f), not(0x1f))
        let success := call(gas(), target, value, scratch, ctxlen, 0, 0)
        let retlen := returndatasize()
        if iszero(success) {
            // FailedCall(target, selector, returndata)
            // 0x20577b07 = FailedCall(address,bytes4,bytes)
            mstore(scratch, shl(224, 0x20577b07))
            mstore(add(scratch, 0x04), target)
            mstore(add(scratch, 0x24), selector)
            mstore(add(scratch, 0x44), 0x60)
            mstore(add(scratch, 0x64), retlen)
            mstore(add(add(scratch, 0x84), retlen), 0)
            returndatacopy(add(scratch, 0x84), 0, retlen)
            revert(scratch, add(0x84, and(add(retlen, 0x1f), not(0x1f))))
        }

        if lt(retlen, 0x60) { revert(0, 0) }
        returndatacopy(scratch, 0, retlen)

        // Strictly validate the exact ABI layout for (bytes, uint). The returned
        // byte array can then point directly into the copied returndata.
        if iszero(eq(mload(scratch), 0x40)) { revert(0, 0) }
        let len1 := mload(add(scratch, 0x40))
        if gt(len1, sub(retlen, 0x60)) { revert(0, 0) }
        let pad1 := and(add(len1, 0x1f), not(0x1f))
        if iszero(eq(retlen, add(0x60, pad1))) { revert(0, 0) }
        output := add(scratch, 0x40)
        credit := mload(add(scratch, 0x20))

        let retend := and(add(add(scratch, retlen), 0x1f), not(0x1f))
        if gt(retend, inputend) { inputend := retend }
        mstore(0x40, inputend)
    }
}

/// @title RawNodeCalls
/// @notice Low-level inter-node call helpers without target authorization.
abstract contract RawNodeCalls {
    /// @notice Try a raw low-level call to another node and return whether it succeeded.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return success True if the low-level call succeeded.
    function tryRawCall(uint node, uint value, bytes memory data) internal returns (bool success) {
        address addr = Nodes.addr(node);
        (success, ) = payable(addr).call{value: value}(data);
    }

    /// @notice Make a raw low-level call to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function rawCall(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        address addr = Nodes.addr(node);
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) revert FailedCall(addr, bytes4(data), out);
    }

    /// @notice Make a raw low-level read-only query to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful query.
    function rawQuery(uint node, bytes memory data) internal view returns (bytes memory out) {
        bool success;
        address addr = Nodes.addr(node);
        (success, out) = addr.staticcall(data);
        if (!success) revert FailedCall(addr, bytes4(data), out);
    }

}

/// @title NodeCalls
/// @notice Trusted low-level inter-node calls backed by a host-provided node policy.
abstract contract NodeCalls is RawNodeCalls, TrustAccess {
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
