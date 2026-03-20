// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES} from "./Base.sol";
import {AssetAmount, BALANCE_KEY, Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

bytes32 constant NAME = "unstakeBalanceToBalance";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract UnstakeBalanceToBalance is CommandBase {
    uint internal immutable unstakeBalanceToBalanceId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, unstakeBalanceToBalanceId, BALANCES, BALANCES);
    }

    function unstakeBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function unstakeBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(unstakeBalanceToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, BALANCE_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.balanceFrom(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            AssetAmount memory out = unstakeBalanceToBalance(c.account, balance, route);
            if (out.amount > 0) writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
