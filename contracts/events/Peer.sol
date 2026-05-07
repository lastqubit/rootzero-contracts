// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI =
    "event Peer(uint indexed host, uint id, string name, bytes32 shape, string request, string response, bool acceptsValue)";

/// @notice Emitted once per peer during host deployment to publish its request and response schemas.
abstract contract PeerEvent is EventEmitter {
    /// @param host Host node ID that owns this peer.
    /// @param id Peer node ID.
    /// @param name Human-readable peer name.
    /// @param shape Prime block counts as `request:response`; global blocks are excluded.
    /// @param request Schema DSL string describing the peer request shape.
    /// @param response Schema DSL string describing the peer response shape.
    /// @param acceptsValue Whether the peer entrypoint accepts nonzero `msg.value`.
    event Peer(uint indexed host, uint id, string name, bytes32 shape, string request, string response, bool acceptsValue);

    constructor() {
        emit EventAbi(ABI);
    }
}



