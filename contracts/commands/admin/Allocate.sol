// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {ALLOCATION, ALLOCATION_KEY, BlockRef, HostAmount} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
import {ensureAssetRef} from "../../utils/Assets.sol";
using Blocks for BlockRef;

string constant NAME = "allocate";

abstract contract Allocate is CommandBase {
    uint internal immutable allocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ALLOCATION, allocateId, SETUP, SETUP);
    }

    function allocate(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function allocate(CommandContext calldata c) external payable onlyAdmin(c.account) onlyCommand(allocateId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != ALLOCATION_KEY) break;
            HostAmount memory v = ref.toAllocationValue(c.request);
            allocate(v.host, v.asset, v.meta, v.amount);
            i = ref.end;
        }
        return done(0, i);
    }
}
