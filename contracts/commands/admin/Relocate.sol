// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "relocate";

abstract contract Relocate is CommandBase {
    uint internal immutable relocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Funding, relocateId, Channels.Setup, Channels.Setup);
    }

    function relocate(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(relocateId, c.target) returns (bytes memory) {
        Cursor memory fundings = Cursors.openRun(c.request, 0, Keys.Funding, 1);

        while (fundings.i < fundings.end) {
            (uint host, uint amount) = fundings.unpackFunding();
            callTo(host, amount, "");
        }

        return fundings.complete();
    }
}




