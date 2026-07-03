// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { NodeCalls } from "../core/Calls.sol";
import { PortEvent } from "../events/Port.sol";
import { LabeledEvent } from "../events/Labeled.sol";
import { Nodes } from "../utils/Nodes.sol";

/// @title PortBase
/// @notice Abstract base for peer-facing rootzero ports.
/// Ports handle inter-host operations between cooperating hosts.
/// Access is restricted to trusted peer callers via `onlyPeer`.
abstract contract PortBase is NodeCalls, PortEvent, LabeledEvent {
    /// @dev Thrown when the commander attempts to call a port entrypoint directly.
    error CommanderNotAllowed();

    /// @dev Restrict execution to trusted callers, excluding the commander.
    modifier onlyPeer() {
        if (msg.sender == commander) revert CommanderNotAllowed();
        enforceCaller(msg.sender);
        _;
    }

    /// @notice Derive the deterministic node ID for a port selector on this contract.
    /// @param selector Port entrypoint selector.
    /// @return Port node ID.
    function portId(bytes4 selector) internal view returns (uint) {
        return Nodes.toPort(selector, address(this));
    }
}
