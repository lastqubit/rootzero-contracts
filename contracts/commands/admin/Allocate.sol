// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "allocate";

/// @title Allocate
/// @notice Admin command that applies cross-host allocation entries via a virtual hook.
/// Each ALLOCATION block in the request calls `allocate`. Only callable by the admin account.
abstract contract Allocate is CommandBase {
    uint internal immutable allocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Allocation, allocateId, State.Empty, State.Empty, false);
    }

    /// @dev Override to apply a single allocation entry.
    /// Called once per ALLOCATION block in the request.
    function allocate(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function allocate(CommandContext calldata c) external onlyAdmin(c.account) onlyCommand(allocateId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (uint host, bytes32 asset, bytes32 meta, uint amount) = request.unpackAllocation();
            allocate(host, asset, meta, amount);
        }

        request.complete();
        return "";
    }
}






