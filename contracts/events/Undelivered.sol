// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host records an undelivered portal message.
abstract contract UndeliveredEvent is EventEmitter {
    string private constant ABI = "event Undelivered(uint indexed host, bytes32 key, bytes32 digest)";

    /// @param host Host node ID that owns the undelivered message.
    /// @param key Delivery lookup key.
    /// @param digest Digest of the undelivered message.
    event Undelivered(uint indexed host, bytes32 key, bytes32 digest);

    constructor() {
        emit EventAbi(ABI);
    }
}
