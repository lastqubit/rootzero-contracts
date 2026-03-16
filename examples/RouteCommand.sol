// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";
import {CommandContext} from "../contracts/Commands.sol";
import {toCommandId} from "../contracts/Utils.sol";

bytes32 constant NAME = "myCommand";

// A route block is a convenient way to pass command-specific parameters in the request payload.
string constant ROUTE = "route(uint foo, uint bar)";

contract ExampleHost is Host {
    // Each custom command needs its own deterministic id so the host can route calls to it safely.
    uint immutable myCommandId = toCommandId(NAME, address(this));

    constructor(address cmdr, address disc) Host(cmdr, disc, 1, "example") {
        // Register the command during deployment so clients can discover its name, schema, and channels.
        emit Command(host, NAME, ROUTE, myCommandId, 0, 0);
    }

    // The external function name should match the command name that was announced in the Command event.
    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        // In this example, `c.request` is expected to contain route blocks carrying `foo` and `bar`.
        c.request;
        return "";
    }
}
