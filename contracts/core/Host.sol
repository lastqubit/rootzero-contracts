// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AccessControl } from "./Access.sol";
import { Authorize } from "../commands/admin/Authorize.sol";
import { Unauthorize } from "../commands/admin/Unauthorize.sol";
import { RelocatePayable } from "../commands/admin/Relocate.sol";
import { HostAnnouncedEvent } from "../events/HostAnnounced.sol";
import { IHostDiscovery } from "../interfaces/IHostDiscovery.sol";
import { Ids } from "../utils/Ids.sol";

/// @notice Mixin that allows a contract to act as a host discovery registry.
/// Hosts call `announceHost` on a discovery contract to register themselves.
abstract contract HostDiscovery is HostAnnouncedEvent, IHostDiscovery {
    /// @notice Announce this host to the discovery registry.
    /// Validates that `id` matches `msg.sender` before emitting.
    /// @param id Host node ID (must equal `Ids.toHost(msg.sender)`).
    /// @param blocknum Block number at which the host was deployed.
    /// @param version Protocol version the host implements.
    /// @param namespace Human-readable namespace string for the host.
    function announceHost(uint id, uint blocknum, uint16 version, string calldata namespace) external {
        emit HostAnnounced(Ids.host(id, msg.sender), blocknum, version, namespace);
    }
}

/// @title Host
/// @notice Abstract base contract for rootzero host implementations.
/// Inherits admin command support (authorize, unauthorize, relocatePayable) and
/// optionally announces itself to a discovery contract at deployment.
/// Accepts native ETH payments via the `receive` function.
abstract contract Host is Authorize, Unauthorize, RelocatePayable {
    /// @param cmdr Commander address; passed to `AccessControl`.
    ///        If `cmdr` is a deployed contract, the host calls `announceHost`
    ///        on it during construction to register with the discovery registry.
    /// @param version Protocol version number to publish in the announcement.
    /// @param namespace Human-readable namespace string for the host.
    constructor(address cmdr, uint16 version, string memory namespace) AccessControl(cmdr) {
        if (cmdr == address(0) || cmdr == address(this) || cmdr.code.length == 0) return;
        IHostDiscovery(cmdr).announceHost(host, block.number, version, namespace);
    }

    /// @notice Accept native ETH transfers (e.g. from command value flows).
    receive() external payable {}
}
