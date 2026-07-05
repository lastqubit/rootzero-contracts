// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host resolves a previously recorded key.
abstract contract ResolvedEvent is EventEmitter {
    string private constant ABI = "event Resolved(uint indexed host, bytes32 key)";

    /// @param host Host node ID that owns the resolved key.
    /// @param key Resolution lookup key.
    event Resolved(uint indexed host, bytes32 key);

    constructor() {
        emit EventAbi(ABI);
    }
}
