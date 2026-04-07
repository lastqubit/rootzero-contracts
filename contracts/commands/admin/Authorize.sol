// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "authorize";

abstract contract Authorize is CommandBase {
    uint internal immutable authorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Node, authorizeId, Channels.Setup, Channels.Setup);
    }

    function authorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(authorizeId, c.target) returns (bytes memory) {
        Cursor memory nodes = Cursors.openStream(c.request, 0);
        while (nodes.i < nodes.end) {
            if (!nodes.isAt(Keys.Node)) break;
            uint node = nodes.unpackNode();
            access(node, true);
        }
        return nodes.complete();
    }
}



