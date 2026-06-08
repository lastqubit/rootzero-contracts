// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted once per peer during host deployment to publish its request and response schemas.
abstract contract PeerEvent is EventEmitter {
    string private constant ABI =
        "event Peer(uint indexed host, uint id, bytes32 shape, string request, string response, bool funded)";

    /// @param host Host node ID that owns this peer.
    /// @param id Peer node ID.
    /// @param shape Per-operation block counts encoded as `request:response`.
    /// @param request Schema DSL string describing the input request run, or empty if none.
    /// @param response Schema DSL string describing the peer response shape.
    /// @param funded Whether the peer entrypoint accepts nonzero `msg.value`.
    event Peer(uint indexed host, uint id, bytes32 shape, string request, string response, bool funded);

    constructor() {
        emit EventAbi(ABI);
    }
}
