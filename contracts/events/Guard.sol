// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted once per guard action during host deployment to publish its request schema.
abstract contract GuardEvent is EventEmitter {
    string private constant ABI = "event Guard(uint indexed host, uint id, string request)";

    /// @param host Host node ID that owns this guard action.
    /// @param id Guard action node ID.
    /// @param request Schema DSL string describing the guard action request shape.
    event Guard(uint indexed host, uint id, string request);

    constructor() {
        emit EventAbi(ABI);
    }
}
