// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {RoutePayableHook} from "../core/Portal.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title RelayPayable
/// @notice Command that forwards one RELAY block to a host-defined relay hook.
/// Reverts unless the request contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayPayable is CommandBase, Payable, RoutePayableHook {
    uint internal immutable relayPayableId = commandId(this.relayPayable.selector);

    constructor() {
        emit Command(host, relayPayableId, "1:0:0", Schemas.Relay, Keys.Any, Keys.Empty, true);
        emit Labeled(relayPayableId, bytes32(0), "relayPayable");
    }

    /// @notice Relay one RELAY request block with the command account and current state.
    /// @param c Command context; `c.request` must contain exactly one RELAY block.
    /// @return output Empty output state.
    function relayPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory output) {
        (Cur memory request, ) = Cursors.init(c.request, 1, 1);
        Budget memory budget = openValue();

        (uint portal, uint resources, bytes memory context) = request.relayToContext(c.account, c.state);
        route(portal, resources, context, budget);

        closeValue(c.account, budget);
        request.complete();
        return "";
    }
}
