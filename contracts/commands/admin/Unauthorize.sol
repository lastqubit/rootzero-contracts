// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, SETUP} from "../Base.sol";
import {BlockRef, NODE, NODE_KEY} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
using Blocks for BlockRef;

bytes32 constant NAME = "unauthorize";

abstract contract Unauthorize is CommandBase {
    uint internal immutable unauthorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, NODE, unauthorizeId, SETUP, SETUP);
    }

    function unauthorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(unauthorizeId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != NODE_KEY) break;
            uint node = ref.unpackNode(c.request);
            access(node, false);
            i = ref.end;
        }
        return done(0, i);
    }
}
