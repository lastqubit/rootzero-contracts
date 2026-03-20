// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, SETUP} from "./Base.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

bytes32 constant NAME = "create";

abstract contract Create is CommandBase {
    uint internal immutable createId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, createId, SETUP, SETUP);
    }

    function create(bytes32 account, DataRef memory rawRoute) internal virtual;

    function create(CommandContext calldata c) external payable onlyCommand(createId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            (DataRef memory ref, uint next) = Data.from(c.request, i);
            if (ref.key != ROUTE_KEY) break;
            create(c.account, ref);
            i = next;
        }

        return done(0, i);
    }
}
