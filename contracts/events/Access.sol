// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Access(uint indexed host, uint node, bool trusted)";

/// @notice Emitted when a node's authorization status changes on a host.
abstract contract AccessEvent is EventEmitter {
    /// @param host Host node ID where the authorization change occurred.
    /// @param node Node ID that was authorized or deauthorized.
    /// @param trusted True if the node was authorized, false if deauthorized.
    event Access(uint indexed host, uint node, bool trusted);

    constructor() {
        emit EventAbi(ABI);
    }
}



