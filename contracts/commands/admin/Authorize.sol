// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { Channels } from "../../utils/Channels.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
using Blocks for Block;

string constant NAME = "authorize";

abstract contract Authorize is CommandBase {
    uint internal immutable authorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Node, authorizeId, Channels.Setup, Channels.Setup);
    }

    function authorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(authorizeId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Node) break;
            uint node = ref.unpackNode();
            access(node, true);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
