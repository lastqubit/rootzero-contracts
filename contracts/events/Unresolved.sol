// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host records a portal message awaiting resolution.
abstract contract UnresolvedEvent is EventEmitter {
    string private constant ABI = "event Unresolved(uint indexed host, bytes32 key, bytes32 digest)";

    /// @param host Host node ID that owns the unresolved message.
    /// @param key Resolution lookup key.
    /// @param digest Digest of the unresolved message.
    event Unresolved(uint indexed host, bytes32 key, bytes32 digest);

    constructor() {
        emit EventAbi(ABI);
    }
}
