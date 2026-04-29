// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI =
    "event Command(uint indexed host, uint id, string name, string request, bytes4 state, bytes4 output, bool acceptsValue)";

/// @notice Emitted once per command during host deployment to publish its request schema and state keys.
abstract contract CommandEvent is EventEmitter {
    /// @param host Host node ID that owns this command.
    /// @param id Command node ID.
    /// @param name Human-readable command name.
    /// @param request Schema DSL string describing the request shape.
    /// @param state Block key expected for input state, or `Keys.Empty`.
    /// @param output Block key produced for output state, or `Keys.Empty`.
    /// @param acceptsValue Whether the command entrypoint accepts nonzero `msg.value`.
    event Command(
        uint indexed host,
        uint id,
        string name,
        string request,
        bytes4 state,
        bytes4 output,
        bool acceptsValue
    );

    constructor() {
        emit EventAbi(ABI);
    }
}
