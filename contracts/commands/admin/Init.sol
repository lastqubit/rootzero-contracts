// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {Data, DataRef} from "../../Blocks.sol";

string constant NAME = "init";

abstract contract Init is CommandBase {
    uint internal immutable initId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, initId, SETUP, SETUP);
    }

    function init(DataRef memory rawRoute) internal virtual;

    function init(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(initId, c.target) returns (bytes memory) {
        (DataRef memory route, uint q) = Data.routeFrom(c.request, 0);
        init(route);
        return done(0, q);
    }
}
