// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, State} from "./Base.sol";
import {Cursors, Cur, HostAmount} from "../Cursors.sol";
string constant NAME = "supply";

using Cursors for Cur;

/// @title Supply
/// @notice Command that processes each CUSTODY state block through a virtual hook.
/// Used to move assets out of cross-host custody positions (e.g. to settle or redeem them).
/// Produces no output state.
abstract contract Supply is CommandBase {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, State.Custodies, State.Empty);
    }

    /// @notice Override to consume or supply a single custody position.
    /// Called once per CUSTODY block in state.
    /// @param account Caller's account identifier.
    /// @param value Decoded custody position (host, asset, meta, amount).
    function supply(bytes32 account, HostAmount memory value) internal virtual;

    /// @notice Execute the supply command.
    function supply(CommandContext calldata c) external payable onlyCommand(supplyId, c.target) returns (bytes memory) {
        (Cur memory state, , ) = cursor(c.state, 1);
        
        while (state.i < state.bound) {
            HostAmount memory value = state.unpackCustodyValue();
            supply(c.account, value);
        }

        state.complete();
        return "";
    }
}

