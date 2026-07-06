// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host recovers a previously recorded key.
abstract contract RecoveredEvent is EventEmitter {
    string private constant ABI = "event Recovered(uint indexed host, bytes32 key)";

    /// @param host Host node ID that owns the recovered key.
    /// @param key Recovery lookup key.
    event Recovered(uint indexed host, bytes32 key);

    constructor() {
        emit EventAbi(ABI);
    }
}
