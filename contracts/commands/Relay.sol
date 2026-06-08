// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract DispatchPayableHook {
    /// @notice Override to dispatch an encoded payload to `chain`.
    /// @param chain Destination chain node ID.
    /// @param resources Chain-adapter-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param budget Source-chain native-value budget available for transport
    /// fees and destination resource funding.
    function dispatch(uint chain, uint resources, bytes memory payload, Budget memory budget) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block to a host-defined relay hook.
/// Reverts unless the request contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayPayable is CommandBase, Payable, DispatchPayableHook {
    uint internal immutable relayPayableId = commandId(this.relayPayable.selector);

    constructor() {
        emit Command(host, relayPayableId, "1:0:0", Schemas.Relay, Keys.Any, Keys.Empty, false, true);
        emit Labeled(relayPayableId, bytes32(0), "relayPayable");
    }

    /// @notice Relay one RELAY request block with the command account and current state.
    /// @param c Command context; `c.request` must contain exactly one RELAY block.
    /// @return output Empty output state.
    function relayPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory output) {
        (Cur memory request, ) = Cursors.init(c.request, 0, 1, 1);
        Budget memory budget = valueBudget();

        (uint chain, uint resources, bytes memory pipe) = request.relayToPipe(c.account, c.state);
        dispatch(chain, resources, pipe, budget);
        
        settleValue(c.account, budget);
        request.complete();
        return "";
    }
}
