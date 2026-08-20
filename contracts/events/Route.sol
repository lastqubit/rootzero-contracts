// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host updates a portal route.
abstract contract RouteEvent is EventEmitter {
    string private constant ABI = "event Route(uint indexed host, uint portal, uint status)";

    /// @param host Host node ID that owns the route.
    /// @param portal Destination portal implementation's host ID.
    /// @param status Route status. Zero means inactive; nonzero means active.
    event Route(uint indexed host, uint portal, uint status);

    constructor() {
        emit EventAbi(ABI);
    }
}
