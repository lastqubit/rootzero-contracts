// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { NodeCalls } from "../core/Calls.sol";
import { EndpointBase } from "../core/Endpoint.sol";
import { Nodes } from "../utils/Nodes.sol";

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
    function port(
        string memory name,
        bytes9 input,
        bytes9 output,
        bytes4 selector,
        bool funded
    ) internal returns (uint id, bytes32 descriptor) {
        if (selector == bytes4(0)) {
            selector = bytes4(keccak256(bytes(string.concat(name, "(bytes)"))));
        }
        id = Nodes.toPort(selector, address(this));
        descriptor = endpoint(bytes9(0), input, output, funded, false);
        defineEndpoint(host, id, descriptor, name);
    }
}
