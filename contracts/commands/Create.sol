// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Blocks, Cursor } from "../Blocks.sol";

string constant NAME = "create";

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, createId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to create or initialize an object described by `input`.
    /// Called once per top-level request item.
    function create(bytes32 account, Cursor memory input) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        Cursor memory input;
        while (input.cursor < c.request.length) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            create(c.account, input);
        }

        return done(0, input.cursor);
    }
}
