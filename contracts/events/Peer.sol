// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI =
    "event Peer(uint indexed host, string name, string schema, uint pid, bool acceptsValue)";

/// @notice Emitted once per peer during host deployment to publish its schema.
abstract contract PeerEvent is EventEmitter {
    /// @param host Host node ID that owns this peer.
    /// @param name Human-readable peer name.
    /// @param schema Schema DSL string describing the peer request shape.
    /// @param pid Peer node ID.
    /// @param acceptsValue Whether the peer entrypoint accepts nonzero `msg.value`.
    event Peer(uint indexed host, string name, string schema, uint pid, bool acceptsValue);

    constructor() {
        emit EventAbi(ABI);
    }
}



