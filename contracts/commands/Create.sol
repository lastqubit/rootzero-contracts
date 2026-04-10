// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

string constant NAME = "create";

using Cursors for Cur;

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, createId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to create or initialize an object described by `input`.
    /// Called once per top-level request item.
    function create(bytes32 account, Cur memory input) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            create(c.account, request);
        }

        request.complete();
        return "";
    }
}






