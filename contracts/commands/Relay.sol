// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract RelayPayableHook {
    /// @notice Override to relay `steps` to `chain` with the current account and state.
    /// @param chain Destination chain node ID.
    /// @param resources Chain-adapter-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param account Command account identifier.
    /// @param state Current command state block stream.
    /// @param steps Embedded destination step block stream.
    /// @param budget Source-chain native-value budget available for transport
    /// fees and destination resource funding.
    function relay(
        uint chain,
        uint resources,
        bytes32 account,
        bytes calldata state,
        bytes calldata steps,
        Budget memory budget
    ) internal virtual;
}

/// @title RelayPayable
/// @notice Command that forwards one RELAY block to a host-defined relay hook.
/// Reverts unless the request contains exactly one RELAY block, preventing
/// the same state from being duplicated across multiple relays.
/// Produces no output state.
abstract contract RelayPayable is CommandBase, Payable, RelayPayableHook {
    string private constant NAME = "relayPayable";

    uint internal immutable relayPayableId = commandId(NAME);

    constructor() {
        emit Command(host, relayPayableId, NAME, "1:0:0", Schemas.Relay, Keys.Any, Keys.Empty, false, true);
    }

    /// @notice Relay one RELAY request block with the command account and current state.
    /// @param c Command context; `c.request` must contain exactly one RELAY block.
    /// @return output Empty output state.
    function relayPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory output) {
        (Cur memory request, ) = Cursors.init(c.request, 0, 1, 1);
        Budget memory budget = valueBudget();

        (uint chain, uint resources, bytes calldata steps) = request.unpackRelay();
        relay(chain, resources, c.account, c.state, steps, budget);
        request.complete();
        return "";
    }
}
