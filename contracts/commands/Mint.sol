// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BALANCES, CommandBase, CommandContext, SETUP} from "./Base.sol";
import {ROUTE_KEY} from "../Schema.sol";
import {Data, DataRef, Writers, Writer} from "../Blocks.sol";
using Writers for Writer;

string constant NAME = "mint";

abstract contract Mint is CommandBase {
    uint internal immutable mintId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, mintId, SETUP, BALANCES);
    }

    function mint(
        bytes32 account,
        DataRef memory rawRoute
    ) internal virtual returns (bytes32 asset, bytes32 meta, uint amount);

    function mint(CommandContext calldata c) external payable onlyCommand(mintId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, q, ROUTE_KEY);

        while (q < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            (bytes32 asset, bytes32 meta, uint amount) = mint(c.account, route);
            if (amount > 0) writer.appendBalance(asset, meta, amount);
        }

        return writer.finish();
    }
}
