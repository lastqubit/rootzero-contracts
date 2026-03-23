// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../contracts/Commands.sol";
import {AssetAmount, AMOUNT} from "../contracts/Schema.sol";
import {Data, DataRef} from "../contracts/Blocks.sol";

using Data for DataRef;

string constant NAME = "myCommand";

string constant ROUTE = "route(uint rate)";
string constant REQUEST = string.concat(ROUTE, ">", AMOUNT);

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, REQUEST, myCommandId, 0, 0);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        (DataRef memory route, ) = Data.routeFrom(c.request, 0);
        uint rate = uint(route.unpackRoute32());
        (bytes32 asset, bytes32 meta, uint amount) = route.innerAmount();
        return "";
    }
}
