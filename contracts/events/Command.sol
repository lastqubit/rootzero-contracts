// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI =
    "event Command(uint indexed host, string name, string schema, uint id, uint8 stateIn, uint8 stateOut, bool acceptsValue)";

/// @notice Emitted once per command during host deployment to publish its schema and state types.
abstract contract CommandEvent is EventEmitter {
    /// @param host Host node ID that owns this command.
    /// @param name Human-readable command name.
    /// @param schema Schema DSL string describing the request shape.
    /// @param id Command node ID.
    /// @param stateIn State type discriminant for the input state (see `State` library).
    /// @param stateOut State type discriminant for the output state.
    /// @param acceptsValue Whether the command entrypoint accepts nonzero `msg.value`.
    event Command(
        uint indexed host,
        string name,
        string schema,
        uint id,
        uint8 stateIn,
        uint8 stateOut,
        bool acceptsValue
    );

    constructor() {
        emit EventAbi(ABI);
    }
}
