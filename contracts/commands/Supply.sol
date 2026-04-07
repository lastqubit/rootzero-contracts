// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cursor, HostAmount, Keys } from "../Cursors.sol";
string constant NAME = "supply";

using Cursors for Cursor;

abstract contract Supply is CommandBase {
    uint internal immutable supplyId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, "", supplyId, Channels.Custodies, Channels.Setup);
    }

    /// @dev Override to consume or supply a single custody position.
    /// Called once per CUSTODY block in state.
    function supply(bytes32 account, HostAmount memory value) internal virtual;

    function supply(CommandContext calldata c) external payable onlyCommand(supplyId, c.target) returns (bytes memory) {
        Cursor memory custodies = Cursors.openRun(c.state, 0, Keys.Custody, 1);
        while (custodies.i < custodies.end) {
            HostAmount memory value = custodies.unpackCustodyValue();
            supply(c.account, value);
        }

        return custodies.complete();
    }
}




