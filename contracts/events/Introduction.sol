// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Introduction(uint indexed host, uint blocknum, uint16 version, string namespace)";

/// @notice Emitted when a host introduces itself to another host.
abstract contract IntroductionEvent is EventEmitter {
    /// @param host Host node ID of the introducing contract.
    /// @param blocknum Block number at which the host was deployed.
    /// @param version Protocol version the host implements.
    /// @param namespace Human-readable namespace string for the host.
    event Introduction(uint indexed host, uint blocknum, uint16 version, string namespace);

    constructor() {
        emit EventAbi(ABI);
    }
}



