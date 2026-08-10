// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {RelayPayableHook} from "../commands/Relay.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PortDispatchPayable
/// @notice Port endpoint that forwards DISPATCH blocks to a host-defined relay hook.
abstract contract PortDispatchPayable is PortBase, RelayPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDispatchPayable", Specs.Dispatch, Specs.Empty, true);
    }

    /// @notice Forward peer-supplied dispatches to the host-defined relay hook.
    /// @dev Relay hooks receive the shared top-level source value
    ///      budget. Any `msg.value` not spent by the hook remains on this host.
    /// @param data DISPATCH block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDispatchPayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);

        while (exec.more()) {
            (uint portal, uint resources, bytes calldata payload) = exec.unpackDispatch(Lanes.Input);
            relayTo(portal, resources, bytes(payload), exec);
        }
        
        return "";
    }
}
