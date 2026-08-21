// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Lanes, Specs} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that relay command contexts.
abstract contract RelayPayableHook {
    /// @notice Override to relay a command context to `portal`.
    /// @param portal Destination portal implementation's host ID. Implementations
    /// may validate or resolve it for their transport.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param account Destination command account.
    /// @param input Input forwarded into the destination context.
    /// @param exec Execution carrying the source state and value available for
    /// transport fees and destination resource funding.
    function relay(
        uint portal,
        uint resources,
        bytes32 account,
        bytes calldata input,
        Execution memory exec
    ) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block without pipeline state.
abstract contract RelayPayable is CommandBase, RelayPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayPayable", Specs.Empty, Specs.Relay, Specs.Empty, 0, Flags.Funded);
    }

    /// @notice Relay one RELAY input block with the command account and empty state.
    function relayPayable(
        bytes calldata context
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 1);
        (uint portal, uint resources, bytes calldata input) = exec.unpackRelay(Lanes.Input);
        relay(portal, resources, exec.account, input, exec);

        return closeCommand(exec);
    }
}

/// @title RelayBalancePayable
/// @notice Command that forwards required BALANCE state with one RELAY block.
/// Reverts unless the input contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayBalancePayable is CommandBase, RelayPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayBalancePayable", Specs.Balance, Specs.Relay, Specs.Empty, 0, Flags.Funded);
    }

    /// @notice Relay one RELAY input block with the command account and current state.
    /// @param context Command context carrying state and exactly one RELAY input block.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function relayBalancePayable(
        bytes calldata context
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 1);
        (uint portal, uint resources, bytes calldata input) = exec.unpackRelay(Lanes.Input);
        relay(portal, resources, exec.account, input, exec);

        return closeCommand(exec);
    }
}
