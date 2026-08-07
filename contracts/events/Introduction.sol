// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when a host introduces itself to another host.
abstract contract IntroductionEvent is EventEmitter {
    string private constant ABI = "event Introduction(uint indexed host, uint peer, bytes32 origin, uint blocknum)";

    /// @param host Host node ID receiving the introduction.
    /// @param peer Host node ID of the introducing contract.
    /// @param origin Transaction-origin address encoded as a chain-agnostic user account.
    /// @param blocknum Block number at which the host was deployed.
    event Introduction(uint indexed host, uint peer, bytes32 origin, uint blocknum);

    constructor() {
        emit EventAbi(ABI);
    }
}



