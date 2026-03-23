// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {SETUP} from "../utils/Channels.sol";
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
        uint q = 0;
        while (q < c.request.length) {
            (DataRef memory ref, uint next) = Data.from(c.request, q);
            if (ref.key != ROUTE_KEY) break;
            destroy(c.account, ref);
            q = next;
        }

        return done(0, q);
    }
}
