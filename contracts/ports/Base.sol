// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { NodeCalls } from "../core/Calls.sol";
import { Specs } from "../codec/Specs.sol";
import { EndpointBase } from "../core/Endpoint.sol";
import { Nodes } from "../utils/Nodes.sol";
import { Selectors } from "../utils/Selectors.sol";
import { Descriptors } from "../codec/Descriptors.sol";

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

    /// @notice Return the host node ID corresponding to the current caller.
    /// @dev Encodes `msg.sender` as a host ID using the local-chain host layout.
    /// @return Host node ID for `msg.sender`.
    function caller() internal view returns (uint) {
        return Nodes.toHost(msg.sender);
    }

    /// @notice Publish port metadata and a default label.
    /// @param name Port entrypoint name and default label. It must exactly
    /// match the Solidity port function name used by the canonical ABI.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param funded Whether the port accepts nonzero native value.
    /// @return id Port node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function port(
        string memory name,
        uint input,
        uint output,
        bool funded
    ) internal returns (uint id, uint descriptor) {
        id = Nodes.toPort(Selectors.port(name), address(this));
        descriptor = endpoint(id, name, Specs.Empty, input, output, 0, funded ? Descriptors.Funded : 0);
    }
}
