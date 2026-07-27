// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { NodeCalls } from "../core/Calls.sol";
import { Specs } from "../codec/Specs.sol";
import { EndpointBase } from "../core/Endpoint.sol";
import { Nodes } from "../utils/Nodes.sol";
import { Selectors } from "../utils/Selectors.sol";

/// @title PortBase
/// @notice Abstract base for peer-facing rootzero ports.
/// Ports handle inter-host operations between cooperating hosts.
/// Access is restricted to trusted peer callers via `onlyPeer`.
abstract contract PortBase is NodeCalls, EndpointBase {
    /// @dev Thrown when the commander attempts to call a port entrypoint directly.
    error CommanderNotAllowed();

    /// @dev Restrict execution to trusted callers, excluding the commander.
    modifier onlyPeer() {
        if (msg.sender == commander) revert CommanderNotAllowed();
        enforceCaller(msg.sender);
        _;
    }

    /// @notice Publish port metadata and a default label.
    /// @param name Default human-readable port label and selector name.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param selector Port ABI selector, or zero to derive it from `name`.
    /// @param funded Whether the port accepts nonzero native value.
    /// @return id Port node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function port(
        string memory name,
        uint input,
        uint output,
        bytes4 selector,
        bool funded
    ) internal returns (uint id, uint descriptor) {
        selector = selector == bytes4(0) ? Selectors.port(name) : selector;
        id = Nodes.toPort(selector, address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, output, funded, false);
    }
}
