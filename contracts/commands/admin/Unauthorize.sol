// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { Channels } from "../../utils/Channels.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
using Blocks for Block;

string constant NAME = "unauthorize";

abstract contract Unauthorize is CommandBase {
    uint internal immutable unauthorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Node, unauthorizeId, Channels.Setup, Channels.Setup);
    }

    function unauthorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(unauthorizeId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Node) break;
            uint node = ref.unpackNode();
            access(node, false);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
