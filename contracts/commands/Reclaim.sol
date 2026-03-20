// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, SETUP} from "./Base.sol";
import {AssetAmount, AMOUNT, ROUTE_EMPTY, ROUTE_KEY, Data, DataRef, Writers, Writer} from "../Blocks.sol";

bytes32 constant NAME = "reclaimBalance";

using Data for DataRef;
using Writers for Writer;

abstract contract ReclaimBalance is CommandBase {
    uint internal immutable reclaimBalanceId = commandId(NAME);

    constructor(string memory maybeRoute) {
        string memory schema = string.concat(bytes(maybeRoute).length == 0 ? ROUTE_EMPTY : maybeRoute, ">", AMOUNT);
        emit Command(host, NAME, schema, reclaimBalanceId, SETUP, BALANCES);
    }

    function reclaimBalance(
        bytes32 account,
        AssetAmount memory amount,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function reclaimBalance(
        CommandContext calldata c
    ) external payable onlyCommand(reclaimBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, i, ROUTE_KEY);

        while (i < end) {
            (DataRef memory route, uint next) = Data.routeFrom(c.request, i);
            AssetAmount memory value = route.innerAmountValue();
            AssetAmount memory out = reclaimBalance(c.account, value, route);
            if (out.amount > 0) writer.appendBalance(out);
            i = next;
        }

        return writer.finish();
    }
}
