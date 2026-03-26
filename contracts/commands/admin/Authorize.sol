// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {NODE, NODE_KEY} from "../../blocks/Schema.sol";
import {Data, DataRef} from "../../Blocks.sol";
using Data for DataRef;

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
            DataRef memory ref = Data.from(c.request, i);
            if (ref.key != NODE_KEY) break;
            uint node = ref.unpackNode();
            access(node, true);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
