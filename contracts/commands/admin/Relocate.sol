// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {BlockRef, FUNDING, FUNDING_KEY} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "relocate";

abstract contract Relocate is CommandBase {
    uint internal immutable relocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, FUNDING, relocateId, SETUP, SETUP);
    }

    function relocate(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(relocateId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != FUNDING_KEY) break;
            (uint host, uint amount) = ref.unpackFunding(c.request);
            callTo(host, amount, "");
            i = ref.end;
        }
        return done(0, i);
    }
}
