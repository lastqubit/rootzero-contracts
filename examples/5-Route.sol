// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../contracts/Commands.sol";
import {AMOUNT} from "../contracts/Schema.sol";
import {toCommandId} from "../contracts/Utils.sol";

bytes32 constant NAME = "myCommand";

// A route block is a convenient way to pass command-specific parameters in the request payload.
string constant ROUTE = "route(uint foo, uint bar)";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = toCommandId(NAME, address(this));

    constructor() {
        emit Command(host, NAME, ROUTE, myCommandId, 0, 0);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {

        return "";
    }
}
