// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Query(uint indexed host, uint id, string name, string input, string output)";

/// @notice Emitted once per query during host deployment to publish its request and response schemas.
abstract contract QueryEvent is EventEmitter {
    /// @param host Host node ID that owns this query.
    /// @param id Query node ID.
    /// @param name Human-readable query name.
    /// @param input Schema DSL string describing the query request shape.
    /// @param output Schema DSL string describing the query response shape.
    event Query(uint indexed host, uint id, string name, string input, string output);

    constructor() {
        emit EventAbi(ABI);
    }
}
