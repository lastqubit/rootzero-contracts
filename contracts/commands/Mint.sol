// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {BALANCES, CommandBase, CommandContext, SETUP} from "./Base.sol";
import {ROUTE_KEY} from "../Schema.sol";
import {Data, DataRef, Writers, Writer} from "../Blocks.sol";
using Writers for Writer;

string constant NAME = "mintToBalances";

abstract contract MintToBalances is CommandBase {
    uint internal immutable mintToBalancesId = commandId(NAME);
    uint internal immutable mntOutScale;

    constructor(string memory route, uint scaledRatio) {
        mntOutScale = scaledRatio;
        emit Command(host, NAME, route, mintToBalancesId, SETUP, BALANCES);
    }

    function mintToBalances(
        bytes32 account,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function mintToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(mintToBalancesId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.request, q, ROUTE_KEY, mntOutScale);

        while (q < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            mintToBalances(c.account, route, writer);
        }

        return writer.finish();
    }
}
