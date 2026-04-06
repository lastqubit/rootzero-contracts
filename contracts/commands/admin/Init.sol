// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor } from "../../Cursors.sol";

string constant NAME = "init";

abstract contract Init is CommandBase {
    uint internal immutable initId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, initId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to run host initialization logic using the decoded input.
    function init(Cursor memory input) internal virtual;

    function init(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(initId, c.target) returns (bytes memory) {
        Cursor memory input = Cursors.openFrom(c.request, 0);
        init(input);
        return done(0, input.next);
    }
}




