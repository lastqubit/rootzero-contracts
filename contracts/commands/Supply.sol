// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Channels} from "./Base.sol";
import {Cursors, Cur, HostAmount} from "../Cursors.sol";
string constant NAME = "supply";

using Cursors for Cur;

abstract contract Supply is CommandBase {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, Channels.Custodies, Channels.Setup);
    }

    /// @dev Override to consume or supply a single custody position.
    /// Called once per CUSTODY block in state.
    function supply(bytes32 account, HostAmount memory value) internal virtual;

    function supply(CommandContext calldata c) external payable onlyCommand(supplyId, c.target) returns (bytes memory) {
        Cur memory state = cursor(c.state, 1);
        
        while (state.i < state.bound) {
            HostAmount memory value = state.unpackCustodyValue();
            supply(c.account, value);
        }

        state.complete();
        return "";
    }
}

