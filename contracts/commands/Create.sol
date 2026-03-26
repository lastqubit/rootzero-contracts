// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {SETUP} from "../utils/Channels.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "create";

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, createId, SETUP, SETUP);
    }

    /// @dev Override to create or initialize an object described by `rawRoute`.
    /// Called once per ROUTE block in the request.
    function create(bytes32 account, DataRef memory rawRoute) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        uint q = 0;
        while (q < c.request.length) {
            DataRef memory ref = Data.from(c.request, q);
            if (ref.key != ROUTE_KEY) break;
            create(c.account, ref);
            q = ref.cursor;
        }

        return done(0, q);
    }
}
