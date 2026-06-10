// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted once per admin command during host deployment to publish its request schema and state keys.
abstract contract AdminEvent is EventEmitter {
    string private constant ABI =
        "event Admin(uint indexed host, uint id, bytes32 shape, string request, bytes4 state, bytes4 output, bool funded)";

    /// @param host Host node ID that owns this admin command.
    /// @param id Command node ID.
    /// @param shape Per-operation block counts encoded as `request:state:output`.
    /// Request and state are each a single run of blocks under the current command convention.
    /// @param request Schema DSL string describing the input request run, or empty if none.
    /// @param state Block key expected for input state, `Keys.Empty`, or `Keys.Any`.
    /// @param output Block key produced for output state, or `Keys.Empty`.
    /// @param funded Whether the command entrypoint accepts nonzero `msg.value`.
    event Admin(
        uint indexed host,
        uint id,
        bytes32 shape,
        string request,
        bytes4 state,
        bytes4 output,
        bool funded
    );

    constructor() {
        emit EventAbi(ABI);
    }
}
