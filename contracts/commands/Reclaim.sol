// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, SETUP} from "./Base.sol";
import {AssetAmount, AMOUNT, ROUTE_EMPTY, ROUTE_KEY, Data, DataRef, Writers, Writer} from "../Blocks.sol";

string constant NAME = "reclaimToBalance";

using Data for DataRef;
using Writers for Writer;

abstract contract ReclaimToBalance is CommandBase {
    uint internal immutable reclaimToBalanceId = commandId(NAME);

    constructor(string memory maybeRoute) {
        string memory schema = string.concat(bytes(maybeRoute).length == 0 ? ROUTE_EMPTY : maybeRoute, ">", AMOUNT);
        emit Command(host, NAME, schema, reclaimToBalanceId, SETUP, BALANCES);
    }

    function reclaimToBalance(
        bytes32 account,
        AssetAmount memory amount,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory out);

    function reclaimToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(reclaimToBalanceId, c.target) returns (bytes memory) {
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, q, ROUTE_KEY);

        while (q < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            AssetAmount memory value = route.innerAmountValue();
            AssetAmount memory out = reclaimToBalance(c.account, value, route);
            if (out.amount > 0) writer.appendBalance(out);
        }

        return writer.finish();
    }
}
