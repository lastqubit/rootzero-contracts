// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "relocate";

abstract contract Relocate is CommandBase {
    uint internal immutable relocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Funding, relocateId, Channels.Setup, Channels.Setup);
    }

    function relocate(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(relocateId, c.target) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (uint host, uint amount) = request.unpackFunding();
            callTo(host, amount, "");
        }

        request.complete();
        return "";
    }
}





