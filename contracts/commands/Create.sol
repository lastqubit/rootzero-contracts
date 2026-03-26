// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "./Base.sol";
import { Channels } from "../utils/Channels.sol";
import { Blocks, Block, Keys } from "../Blocks.sol";
using Blocks for Block;

string constant NAME = "create";

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, createId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to create or initialize an object described by `rawRoute`.
    /// Called once per ROUTE block in the request.
    function create(bytes32 account, Block memory rawRoute) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        uint q = 0;
        while (q < c.request.length) {
            Block memory ref = Blocks.from(c.request, q);
            if (ref.key != Keys.Route) break;
            create(c.account, ref);
            q = ref.cursor;
        }

        return done(0, q);
    }
}
