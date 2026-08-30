// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Specs} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that relay command contexts.
abstract contract RelayPayableHook {
    /// @notice Override to relay a command context and its pipeline continuation.
    /// @dev Relay hooks may forward only EMPTY or BALANCE state. They must not
    /// relay DEBT, POSITION, or other state whose destination handling can fail:
    /// the source state is consumed before destination success is known.
    /// `funds` contains only this handoff STEP's assigned value, not the source
    /// pipeline's complete remaining budget. Implementations must consume or
    /// forward `state`; the command returns empty state when the hook completes.
    /// @param account Destination command account.
    /// @param state Complete state forwarded into the destination context.
    /// @param input Command-specific input supplied by the handoff step.
    /// Implementations define and decode this stream according to their transport.
    /// @param steps Remaining STEP stream owned by the handoff.
    /// @param funds Execution carrying value available for transport fees and
    /// destination resource funding.
    function relay(
        bytes32 account,
        bytes calldata state,
        bytes calldata input,
        bytes calldata steps,
        Execution memory funds
    ) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block without pipeline state.
abstract contract RelayPayable is CommandBase, RelayPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayPayable", Specs.Empty, Specs.Relay, Specs.Empty, Flags.HandoffFunded);
    }

    /// @notice Relay one RELAY input block with the command account and empty state.
    function relayPayable(bytes calldata context) external payable onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);
        (bytes calldata input, bytes calldata steps) = exec.oninput().unpackRelay();
        relay(exec.account, context[0:0], input, steps, exec);
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
        (, descriptor) = command("relayBalancePayable", Specs.Balance, Specs.Relay, Specs.Empty, Flags.HandoffFunded);
    }

    /// @notice Relay one RELAY input block with the command account and current state.
    /// @param context Command context carrying state and exactly one RELAY input block.
    /// @return Empty output state.
    /// @return Native value to add to the caller's budget.
    function relayBalancePayable(bytes calldata context) external payable onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);
        (bytes calldata input, bytes calldata steps) = exec.oninput().unpackRelay();
        relay(exec.account, exec.takeRawState(), input, steps, exec);
        return exec.close();
    }
}
