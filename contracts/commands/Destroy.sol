// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, SETUP} from "./Base.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "destroy";

abstract contract Destroy is CommandBase {
    uint internal immutable destroyId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, destroyId, SETUP, SETUP);
    }

    function destroy(bytes32 account, DataRef memory rawRoute) internal virtual;

    function destroy(CommandContext calldata c) external payable onlyCommand(destroyId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            (DataRef memory ref, uint next) = Data.from(c.request, i);
            if (ref.key != ROUTE_KEY) break;
            destroy(c.account, ref);
            i = next;
        }

        return done(0, i);
    }
}
