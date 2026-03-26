// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, SETUP} from "../utils/Channels.sol";
import {AssetAmount, AMOUNT, ROUTE_KEY, Data, DataRef, Writers, Writer} from "../Blocks.sol";
import {routeSchema1} from "../utils/Utils.sol";

string constant NAME = "reclaimToBalances";

using Data for DataRef;
using Writers for Writer;

abstract contract ReclaimToBalances is CommandBase {
    uint internal immutable reclaimToBalancesId = commandId(NAME);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = routeSchema1(maybeRoute, AMOUNT);
        emit Command(host, NAME, schema, reclaimToBalancesId, SETUP, BALANCES);
    }

    /// @dev Override to reclaim balances described by `rawRoute`.
    /// `amount` is extracted from the route and implementations may append one
    /// or more BALANCE blocks to `out`.
    function reclaimToBalances(
        bytes32 account,
        AssetAmount memory amount,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function reclaimToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(reclaimToBalancesId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.request, q, ROUTE_KEY, outScale);

        while (q < end) {
            DataRef memory route;
            route = Data.routeFrom(c.request, q);
            q = route.cursor;
            AssetAmount memory value = route.innerAmountValue();
            reclaimToBalances(c.account, value, route, writer);
        }

        return writer.finish();
    }
}
