// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cursor } from "../Cursors.sol";

string constant NAME = "create";

using Cursors for Cursor;

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, createId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to create or initialize an object described by `input`.
    /// Called once per top-level request item.
    function create(bytes32 account, Cursor memory input) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        (Cursor memory inputs, ) = Cursors.openInput(c.request, 0);
        while (inputs.i < inputs.end) {
            create(c.account, inputs.take());
        }
        return inputs.complete();
    }
}





