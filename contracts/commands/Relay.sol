// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks, Execution, Executions, CommandBase, Lanes, Specs} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that route funded relay payloads.
abstract contract RoutePayableHook {
    /// @notice Override to route an encoded payload through `portal`.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param funds Execution used only for source value available for transport
    /// fees and destination resource funding.
    function route(uint portal, uint resources, bytes memory payload, Execution memory funds) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block to a host-defined relay hook.
/// Reverts unless the input contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayPayable is CommandBase, RoutePayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayPayable", Specs.Any, Specs.Relay, Specs.Empty, 0, true, false);
    }

    /// @notice Relay one RELAY input block with the command account and current state.
    /// @param state State forwarded into the destination context.
    /// @param input Exactly one RELAY block.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function relayPayable(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 1);
        (uint portal, uint resources, bytes calldata payload) = exec.unpackRelay(Lanes.Input);
        bytes memory context = Blocks.context(account, bytes(state), bytes(payload));

        route(portal, resources, context, exec);

        return close(exec, account);
    }
}
