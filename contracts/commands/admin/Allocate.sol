// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cur, HostAmount, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

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
        Cur memory request = cursor(c.request, 1);

        while (request.i < request.bound) {
            HostAmount memory v = request.unpackAllocationValue();
            allocate(v.host, v.asset, v.meta, v.amount);
        }

        request.complete();
        return "";
    }
}





