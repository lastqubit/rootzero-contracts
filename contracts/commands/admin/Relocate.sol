// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { SETUP } from "../../utils/Channels.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
using Blocks for Block;

string constant NAME = "relocate";

abstract contract Relocate is CommandBase {
    uint internal immutable relocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Funding, relocateId, SETUP, SETUP);
    }

    function relocate(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(relocateId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Funding) break;
            (uint host, uint amount) = ref.unpackFunding();
            callTo(host, amount, "");
            i = ref.cursor;
        }
        return done(0, i);
    }
}
