// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {TrustAccess} from "./Access.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Keys} from "../codec/Keys.sol";
import {Sizes} from "../codec/Specs.sol";
import {max32} from "../utils/Utils.sol";

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @title RawNodeCalls
/// @notice Low-level inter-node call helpers without target authorization.
abstract contract RawNodeCalls {
    /// @notice Try a raw low-level call to another node and return whether it succeeded.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return success True if the low-level call succeeded.
    function tryRawCall(uint node, uint128 value, bytes memory data) internal returns (bool success) {
        address addr = Nodes.addr(node);
        (success, ) = payable(addr).call{value: value}(data);
    }

    /// @notice Make a raw low-level call to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function rawCall(uint node, uint128 value, bytes memory data) internal returns (bytes memory out) {
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
    function tryTrustedCall(uint node, uint128 value, bytes memory data) internal returns (bool success) {
        return tryRawCall(ensureTrusted(node), value, data);
    }

    /// @notice Make a trusted low-level call to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function trustedCall(uint node, uint128 value, bytes memory data) internal returns (bytes memory out) {
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

/// @title CommandCalls
/// @notice Trusted command-call helpers for contracts that route command nodes.
abstract contract CommandCalls is NodeCalls {
    /// @dev Build `command(bytes)` calldata and its nested CONTEXT block in one allocation.
    /// Threaded state is copied from memory and step input directly from calldata.
    function encodeCommandCall(
        bytes4 selector,
        bytes32 account,
        bytes memory state,
        bytes calldata input
    ) internal pure returns (bytes memory data) {
        uint contextLen = max32(Sizes.B32 + 2 * Sizes.Header + state.length + input.length);
        uint paddedContextLen = (contextLen + 31) & ~uint(31);
        uint dataLen = 4 + 64 + paddedContextLen;

        // Reserve one scratch word because the final eight-byte block header is
        // written with mstore. Exclude that word from the returned calldata.
        data = new bytes(dataLen + 32);

        uint contextKey = uint32(Keys.Context);
        uint bytesKey = uint32(Keys.Bytes);
        assembly ("memory-safe") {
            mstore(data, dataLen)
            let out := add(data, 0x20)

            // ABI envelope for command(bytes).
            mstore(out, selector)
            mstore(add(out, 0x04), 0x20)
            mstore(add(out, 0x24), contextLen)

            // CONTEXT(account, BYTES(state), BYTES(input)).
            let context := add(out, 0x44)
            mstore(context, or(shl(224, contextKey), shl(192, sub(contextLen, 8))))
            mstore(add(context, 0x08), account)

            let stateBlock := add(context, 0x28)
            let stateLen := mload(state)
            mstore(stateBlock, or(shl(224, bytesKey), shl(192, stateLen)))
            mcopy(add(stateBlock, 0x08), add(state, 0x20), stateLen)

            let inputBlock := add(add(stateBlock, 0x08), stateLen)
            let inputLen := input.length
            mstore(inputBlock, or(shl(224, bytesKey), shl(192, inputLen)))
            calldatacopy(add(inputBlock, 0x08), input.offset, inputLen)
        }
    }

    /// @notice Encode and call a trusted command node.
    /// @param command Command node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param account Command account identifier.
    /// @param state Current command state block stream.
    /// @param input Command input block stream.
    /// @return nextState Decoded command output state block stream.
    /// @return credit Trusted native value to add to the caller's execution budget.
    function callCommand(
        uint command,
        uint128 value,
        bytes32 account,
        bytes memory state,
        bytes calldata input
    ) internal returns (bytes memory nextState, uint credit) {
        bytes4 selector = Nodes.commandSelector(command);
        bytes memory data = encodeCommandCall(selector, account, state, input);
        return abi.decode(trustedCall(command, value, data), (bytes, uint));
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
    function tryCallPort(uint port, uint128 value, bytes memory input) internal returns (bool success) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return tryTrustedCall(port, value, data);
    }

    /// @notice Try to encode and call a trusted port node by copying input from calldata.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return success True if the low-level port call succeeded.
    function tryCallPortCopy(uint port, uint128 value, bytes calldata input) internal returns (bool success) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return tryTrustedCall(port, value, data);
    }

    /// @notice Encode and call a trusted port node.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return Decoded port output block stream.
    function callPort(uint port, uint128 value, bytes memory input) internal returns (bytes memory) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return abi.decode(trustedCall(port, value, data), (bytes));
    }

    /// @notice Encode and call a trusted port node by copying input from calldata.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return Decoded port output block stream.
    function callPortCopy(uint port, uint128 value, bytes calldata input) internal returns (bytes memory) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return abi.decode(trustedCall(port, value, data), (bytes));
    }
}
