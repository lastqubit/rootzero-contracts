// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host records an outbound dispatch reference.
abstract contract DispatchEvent is EventEmitter {
    string private constant ABI = "event Dispatch(uint indexed host, uint portal, uint resources, bytes32 key, bytes32 digest)";

    /// @param host Host node ID that owns the dispatch.
    /// @param portal Destination portal implementation's host ID.
    /// @param resources Chain-specific resources assigned to the dispatch.
    /// @param key Dispatch correlation or recovery lookup key.
    /// @param digest Digest of the dispatched payload or canonical envelope.
    event Dispatch(uint indexed host, uint portal, uint resources, bytes32 key, bytes32 digest);

    constructor() {
        emit EventAbi(ABI);
    }
}
