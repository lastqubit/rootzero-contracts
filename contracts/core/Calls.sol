// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AccessControl} from "./Access.sol";
import {Ids} from "../utils/Ids.sol";

/// @dev Emitted when a trusted inter-node call fails.
/// @param addr Contract address that was called.
/// @param selector 4-byte selector of the called function.
/// @param err Revert data returned by the failed call.
error FailedCall(address addr, bytes4 selector, bytes err);

/// @title NodeCalls
/// @notice Shared trusted inter-node call helpers for contracts that can talk to other nodes.
abstract contract NodeCalls is AccessControl {
    /// @notice Return the host node ID corresponding to the current caller.
    /// @dev Encodes `msg.sender` as a host ID using the local-chain host layout.
    /// @return Host node ID for `msg.sender`.
    function caller() internal view returns (uint) {
        return Ids.toHost(msg.sender);
    }

    /// @notice Make a low-level call to an address.
    /// Forwards `value` ETH and `data` to `addr`.
    /// Reverts with `FailedCall` if the call is unsuccessful.
    /// @param addr Contract address to call.
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function callAddr(address addr, uint value, bytes memory data) internal returns (bytes memory out) {
        bool success;
        (success, out) = payable(addr).call{value: value}(data);
        if (!success) revert FailedCall(addr, bytes4(data), out);
    }

    /// @notice Make a low-level read-only query to an address.
    /// Issues a low-level `staticcall` with `data`.
    /// Reverts with `FailedCall` if the call is unsuccessful.
    /// @param addr Contract address to query.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful query.
    function queryAddr(address addr, bytes memory data) internal view returns (bytes memory out) {
        bool success;
        (success, out) = addr.staticcall(data);
        if (!success) revert FailedCall(addr, bytes4(data), out);
    }

    /// @notice Make a trusted call to another node in the network.
    /// Looks up the node's contract address via `ensureTrusted` + `Ids.nodeAddr`,
    /// then issues a low-level call forwarding `value` ETH and `data`.
    /// @param node Node ID of the callee (must be in the authorized set).
    /// @param value Native value to forward in wei.
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful call.
    function callTo(uint node, uint value, bytes memory data) internal returns (bytes memory out) {
        address addr = Ids.nodeAddr(ensureTrusted(node));
        return callAddr(addr, value, data);
    }

    /// @notice Make a trusted query to another node in the network.
    /// Looks up the node's contract address via `ensureTrusted` + `Ids.nodeAddr`,
    /// then issues a low-level `staticcall` with `data`.
    /// @param node Node ID of the callee (must be in the authorized set).
    /// @param data Encoded calldata to send.
    /// @return out Return data from the successful query.
    function queryTo(uint node, bytes memory data) internal view returns (bytes memory out) {
        address addr = Ids.nodeAddr(ensureTrusted(node));
        return queryAddr(addr, data);
    }
}
