// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { Channels } from "../../utils/Channels.sol";
import { HostAmount } from "../../blocks/Schema.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
import { ensureAssetRef } from "../../utils/Assets.sol";
using Blocks for Block;

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
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Allocation) break;
            HostAmount memory v = ref.toAllocationValue();
            allocate(v.host, v.asset, v.meta, v.amount);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
