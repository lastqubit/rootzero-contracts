// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @title NodeCalls
/// @notice Shared low-level inter-node call helpers for contracts that can talk to other nodes.
abstract contract NodeCalls is AccessControl {
    /// @notice Return the host node ID corresponding to the current caller.
    /// @dev Encodes `msg.sender` as a host ID using the local-chain host layout.
    /// @return Host node ID for `msg.sender`.
    function caller() internal view returns (uint) {
        return Nodes.toHost(msg.sender);
    }

    /// @notice Try a raw low-level call to another node and return whether it succeeded.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return success True if the low-level call succeeded.
    function tryRawCall(uint node, uint128 value, bytes memory data) internal returns (bool success) {
        address addr = Nodes.addr(node);
        (success, ) = payable(addr).call{value: value}(data);
    }

    /// @notice Try a trusted low-level call to another node and return whether it succeeded.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return success True if the low-level call succeeded.
    function tryTrustedCall(uint node, uint128 value, bytes memory data) internal returns (bool success) {
        return tryRawCall(ensureTrusted(node), value, data);
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

    /// @notice Make a trusted low-level call to another node and revert when it fails.
    /// @param node Node ID of the callee.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function trustedCall(uint node, uint128 value, bytes memory data) internal returns (bytes memory out) {
        return rawCall(ensureTrusted(node), value, data);
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
    /// @notice Encode and call a trusted command node.
    /// @param command Command node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param account Command account identifier.
    /// @param state Current command state block stream.
    /// @param request Command input block stream.
    /// @return nextState Decoded command output state block stream.
    /// @return transactions Decoded command transaction block stream.
    function callCommand(
        uint command,
        uint128 value,
        bytes32 account,
        bytes memory state,
        bytes calldata request
    ) internal returns (bytes memory nextState, bytes memory transactions) {
        bytes4 selector = Nodes.commandSelector(command);
        bytes memory data = abi.encodeWithSelector(selector, account, state, request);
        return abi.decode(trustedCall(command, value, data), (bytes, bytes));
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
    function tryCallPort(uint port, uint128 value, bytes calldata input) internal returns (bool success) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return tryTrustedCall(port, value, data);
    }

    /// @notice Encode and call a trusted port node.
    /// @param port Port node ID embedding the target selector.
    /// @param value Native value to forward in wei.
    /// @param input Port input block stream.
    /// @return Decoded port output block stream.
    function callPort(uint port, uint128 value, bytes calldata input) internal returns (bytes memory) {
        bytes4 selector = Nodes.portSelector(port);
        bytes memory data = abi.encodeWithSelector(selector, input);
        return abi.decode(trustedCall(port, value, data), (bytes));
    }
}
