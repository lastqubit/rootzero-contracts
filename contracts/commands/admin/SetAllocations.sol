// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {ALLOCATION, ALLOCATION_KEY, BlockRef, HostAmount} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
import {ensureAssetRef} from "../../utils/Assets.sol";
using Blocks for BlockRef;

string constant NAME = "setAllocations";

abstract contract SetAllocations is CommandBase {
    uint internal immutable setAllocationsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ALLOCATION, setAllocationsId, SETUP, SETUP);
    }

    function setAllocation(uint host, bytes32 asset, bytes32 meta, uint amount) internal virtual;

    function setAllocations(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(setAllocationsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != ALLOCATION_KEY) break;
            HostAmount memory v = ref.toAllocationValue(c.request);
            setAllocation(v.host, v.asset, v.meta, v.amount);
            i = ref.end;
        }
        return done(0, i);
    }
}
