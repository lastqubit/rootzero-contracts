// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Flags} from "../codec/Descriptors.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that forward funded dispatch payloads.
abstract contract DispatchPayableHook {
    /// @notice Override to dispatch an encoded payload to `portal`.
    /// @param portal Destination portal implementation's host ID. Implementations
    /// may validate or resolve it for their transport.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param funds Execution used for source value available for transport fees
    /// and destination resource funding.
    function dispatchTo(uint portal, uint resources, bytes memory payload, Execution memory funds) internal virtual;
}

/// @title DispatchPayablePort
/// @notice Port endpoint that forwards DISPATCH blocks to a host-defined dispatch hook.
abstract contract DispatchPayablePort is PortBase, DispatchPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDispatchPayable", Specs.Dispatch, Specs.Empty, Flags.Funded);
    }

    /// @notice Forward peer-supplied dispatches to the host-defined dispatch hook.
    /// @dev Dispatch hooks receive the shared top-level source value
    ///      budget. Any `msg.value` not spent by the hook remains on this host.
    /// @param data DISPATCH block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDispatchPayable(bytes calldata data) external payable onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);

        while (exec.more()) {
            (uint portal, uint resources, bytes calldata payload) = exec.unpackDispatch(Lanes.Input);
            dispatchTo(portal, resources, payload, exec);
        }
        
        return "";
    }
}
