// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, SETUP} from "./Base.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "create";

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, createId, SETUP, SETUP);
    }

    function create(bytes32 account, DataRef memory rawRoute) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        uint q = 0;
        while (q < c.request.length) {
            (DataRef memory ref, uint next) = Data.from(c.request, q);
            if (ref.key != ROUTE_KEY) break;
            create(c.account, ref);
            q = next;
        }

        return done(0, q);
    }
}
