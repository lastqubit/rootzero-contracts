// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { Payable } from "../core/Payable.sol";
import { RoutePayableHook } from "../commands/Relay.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";
import { Budget } from "../utils/Value.sol";

using Cursors for Cur;

/// @title PortDispatchPayable
/// @notice Port endpoint that forwards DISPATCH blocks to a host-defined route hook.
abstract contract PortDispatchPayable is PortBase, Payable, RoutePayableHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDispatchPayable", Keys.Dispatch, Keys.Empty, 0, true);
    }

    /// @notice Forward peer-supplied dispatches to the host-defined route hook.
    /// @dev Route hooks receive the shared top-level source value
    ///      budget. Any `msg.value` not spent by the hook remains on this host.
    /// @param data DISPATCH block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDispatchPayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (uint portal, uint resources, bytes calldata payload) = input.unpackDispatch();
            route(portal, resources, bytes(payload), budget);
        }
        return "";
    }

}
