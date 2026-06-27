// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { Payable } from "../core/Payable.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";
import { DispatchPayableHook } from "../commands/Relay.sol";
import { Budget } from "../utils/Value.sol";

using Cursors for Cur;

interface IPortDispatchPayable {
    function portDispatchPayable(bytes calldata data) external payable returns (bytes memory);
}

/// @title PortDispatchPayable
/// @notice Port endpoint that forwards DISPATCH blocks to a host-defined dispatch hook.
abstract contract PortDispatchPayable is PortBase, Payable, DispatchPayableHook, IPortDispatchPayable {
    uint internal immutable portDispatchPayableId = portId(this.portDispatchPayable.selector);

    constructor() {
        emit Port(host, portDispatchPayableId, "1:0", Schemas.Dispatch, "", true);
        emit Labeled(portDispatchPayableId, bytes32(0), "portDispatchPayable");
    }

    /// @notice Forward peer-supplied dispatches to the host-defined dispatch hook.
    /// @dev Dispatch hooks receive the shared top-level source-chain value
    ///      budget. Any `msg.value` not spent by the hook remains on this host.
    /// @param data DISPATCH block stream supplied by the trusted peer.
    /// @return output Empty response bytes.
    function portDispatchPayable(bytes calldata data) external payable onlyPeer returns (bytes memory output) {
        (Cur memory input, , ) = Cursors.init(data, 1);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (uint chain, uint resources, bytes calldata payload) = input.unpackDispatch();
            dispatch(chain, resources, bytes(payload), budget);
        }

        input.complete();
        return "";
    }

}
