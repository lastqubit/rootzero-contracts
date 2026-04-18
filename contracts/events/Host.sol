// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event HostAnnounced(uint indexed host, uint blocknum, uint16 version, string namespace)";

/// @notice Emitted by the discovery contract when a host registers itself.
abstract contract HostAnnouncedEvent is EventEmitter {
    /// @param host Host node ID of the registering contract.
    /// @param blocknum Block number at which the host was deployed.
    /// @param version Protocol version the host implements.
    /// @param namespace Human-readable namespace string for the host.
    event HostAnnounced(uint indexed host, uint blocknum, uint16 version, string namespace);

    constructor() {
        emit EventAbi(ABI);
    }
}



