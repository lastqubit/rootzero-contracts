// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host announces a route to another chain/domain.
abstract contract RouteEvent is EventEmitter {
    string private constant ABI = "event Route(uint indexed host, uint chain, uint context)";

    /// @param host Host node ID that owns the route.
    /// @param chain Destination chain/domain node ID.
    /// @param context Route context identifier.
    event Route(uint indexed host, uint chain, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
