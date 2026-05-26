// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when a node's authorization status changes on a host.
abstract contract NodeEvent is EventEmitter {
    string private constant ABI = "event Node(uint indexed host, uint node, bool active)";

    /// @param host Host node ID where the authorization change occurred.
    /// @param node Node ID that was authorized or revoked.
    /// @param active True if the node is authorized, false if revoked.
    event Node(uint indexed host, uint node, bool active);

    constructor() {
        emit EventAbi(ABI);
    }
}
