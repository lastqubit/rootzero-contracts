// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {BlockRef, NODE, NODE_KEY} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "authorize";

abstract contract Authorize is CommandBase {
    uint internal immutable authorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, NODE, authorizeId, SETUP, SETUP);
    }

    function authorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(authorizeId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != NODE_KEY) break;
            uint node = ref.unpackNode(c.request);
            access(node, true);
            i = ref.end;
        }
        return done(0, i);
    }
}
