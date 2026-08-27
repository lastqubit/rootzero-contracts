// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Specs} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that relay command contexts.
abstract contract RelayPayableHook {
    /// @notice Override to relay a command context to `portal`.
    /// @dev Relay hooks may forward only EMPTY or BALANCE state. They must not
    /// relay DEBT, POSITION, or other state whose destination handling can fail:
    /// the source state is consumed before destination success is known.
    /// @param portal Destination portal implementation's host ID. Implementations
    /// may validate or resolve it for their transport.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param account Destination command account.
    /// @param state Complete state forwarded into the destination context.
    /// @param input Input forwarded into the destination context.
    /// @param funds Execution carrying value available for transport fees and
    /// destination resource funding.
    function relay(
        uint portal,
        uint resources,
        bytes32 account,
        bytes calldata state,
        bytes calldata input,
        Execution memory funds
    ) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block without pipeline state.
abstract contract RelayPayable is CommandBase, RelayPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayPayable", Specs.Empty, Specs.Relay, Specs.Empty, Flags.Funded);
    }

    /// @notice Relay one RELAY input block with the command account and empty state.
    function relayPayable(bytes calldata context) external payable onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);
        (uint portal, uint resources, bytes calldata input) = exec.oninput().unpackRelay();
        relay(portal, resources, exec.account, context[0:0], input, exec);
        return exec.close();
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
        (, descriptor) = command("relayBalancePayable", Specs.Balance, Specs.Relay, Specs.Empty, Flags.Funded);
    }

    /// @notice Relay one RELAY input block with the command account and current state.
    /// @param context Command context carrying state and exactly one RELAY input block.
    /// @return Empty output state.
    /// @return Native value to add to the caller's budget.
    function relayBalancePayable(bytes calldata context) external payable onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);
        (uint portal, uint resources, bytes calldata input) = exec.oninput().unpackRelay();
        relay(portal, resources, exec.account, exec.takeRawState(), input, exec);
        return exec.close();
    }
}
