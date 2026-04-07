// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cursor } from "../Cursors.sol";

string constant NAME = "remove";

using Cursors for Cursor;

abstract contract Remove is CommandBase {
    uint internal immutable removeId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, removeId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to remove or dismantle an object described by `input`.
    /// Called once per top-level request item.
    function remove(bytes32 account, Cursor memory input) internal virtual;

    function remove(CommandContext calldata c) external payable onlyCommand(removeId, c.target) returns (bytes memory) {
        Cursor memory inputs = Cursors.openInput(c.request, 0, 1);
        while (inputs.i < inputs.end) {
            remove(c.account, inputs.take());
        }
        return inputs.complete();
    }
}





