// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Lane} from "../core/Endpoint.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract RoutePayableHook {
    /// @notice Override to route an encoded payload through `portal`.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param budget Source native-value budget available for transport
    /// fees and destination resource funding.
    function route(uint portal, uint resources, bytes memory payload, Budget memory budget) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block to a host-defined relay hook.
/// Reverts unless the request contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayPayable is CommandBase, Payable, RoutePayableHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("relayPayable", Keys.Any, Keys.Relay, Keys.Empty, 0, true, false);
    }

    /// @notice Relay one RELAY request block with the command account and current state.
    /// @param c Command context; `c.input` must contain exactly one RELAY block.
    /// @return state Empty output state.
    /// @return transactions Remaining native value as a refund transaction stream.
    function relayPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory state, bytes memory transactions) {
        (Cur memory input, , ) = openLane(c.input, descriptor, Lane.Input, 1);
        (uint portal, uint resources, bytes memory context) = input.relayToContext(c.account, c.state);

        Budget memory budget = openValue();
        route(portal, resources, context, budget);

        return ("", closeValue(budget, c.account));
    }
}
