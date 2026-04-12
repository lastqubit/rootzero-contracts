// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title IHostDiscovery
/// @notice Interface implemented by a discovery registry that hosts announce themselves to.
interface IHostDiscovery {
    /// @notice Register or refresh a host entry in the discovery registry.
    /// @param id Host node ID.
    /// @param blocknum Block number at which the announcement was made.
    /// @param version Protocol version the host is running.
    /// @param namespace Human-readable namespace or label for the host.
    function announceHost(uint id, uint blocknum, uint16 version, string calldata namespace) external;
}



