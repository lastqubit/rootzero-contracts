// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {Data, DataRef} from "../../Blocks.sol";

string constant NAME = "destroy";

abstract contract Destroy is CommandBase {
    uint internal immutable destroyId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, destroyId, SETUP, SETUP);
    }

    /// @dev Override to run host teardown or destruction logic using the
    /// decoded route.
    function destroy(DataRef memory rawRoute) internal virtual;

    function destroy(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(destroyId, c.target) returns (bytes memory) {
        DataRef memory route = Data.routeFrom(c.request, 0);
        destroy(route);
        return done(0, route.cursor);
    }
}
