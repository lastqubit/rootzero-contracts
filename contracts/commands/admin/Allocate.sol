// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, HostAmount, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "allocate";

abstract contract Allocate is CommandBase {
    uint internal immutable allocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Allocation, allocateId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to apply a single allocation entry.
    /// Called once per ALLOCATION block in the request.
    function allocate(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function allocate(CommandContext calldata c) external payable onlyAdmin(c.account) onlyCommand(allocateId, c.target) returns (bytes memory) {
        (Cursor memory allocations, ) = Cursors.openRun(c.request, 0, Keys.Allocation);

        while (allocations.i < allocations.end) {
            HostAmount memory v = allocations.unpackAllocationValue();
            allocate(v.host, v.asset, v.meta, v.amount);
        }

        return allocations.complete();
    }
}




