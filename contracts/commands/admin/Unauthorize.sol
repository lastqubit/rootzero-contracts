// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "unauthorize";

abstract contract Unauthorize is CommandBase {
    uint internal immutable unauthorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Node, unauthorizeId, Channels.Setup, Channels.Setup);
    }

    function unauthorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(unauthorizeId, c.target) returns (bytes memory) {
        Cursor memory nodes = Cursors.openStream(c.request, 0);
        while (nodes.i < nodes.end) {
            if (!nodes.isAt(Keys.Node)) break;
            uint node = nodes.unpackNode();
            access(node, false);
        }
        return nodes.complete();
    }
}



