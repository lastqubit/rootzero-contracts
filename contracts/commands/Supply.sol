// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, State} from "./Base.sol";
import {AssetAmount, Cursors, Cur} from "../Cursors.sol";
string constant NAME = "supply";

using Cursors for Cur;

abstract contract SupplyHook {
    /// @notice Override to consume or supply a single custody position.
    /// Called once per CUSTODY_AT block in state.
    /// @param host Decoded custody host node ID.
    /// @param account Caller's account identifier.
    /// @param value Decoded custody asset amount.
    function supply(uint host, bytes32 account, AssetAmount memory value) internal virtual;
}

/// @title Supply
/// @notice Command that processes each CUSTODY_AT state block through a virtual hook.
/// Used to move assets out of cross-host custody positions (e.g. to settle or redeem them).
/// Produces no output state.
abstract contract Supply is CommandBase, SupplyHook {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, State.Custodies, State.Empty, false);
    }

    /// @notice Execute the supply command.
    function supply(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);
        
        while (state.i < state.bound) {
            (uint host, AssetAmount memory value) = state.unpackHostAssetAmountValue();
            supply(host, c.account, value);
        }

        state.complete();
        return "";
    }
}


