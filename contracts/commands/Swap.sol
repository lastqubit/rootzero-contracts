// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, ROUTE_KEY, MINIMUM} from "../blocks/Schema.sol";
import {Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";
import {routeSchema1} from "../utils/Utils.sol";
using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

string constant SEBTB = "swapExactBalanceToBalance";
string constant SECTB = "swapExactCustodyToBalance";

abstract contract SwapExactBalanceToBalance is CommandBase {
    uint internal immutable swapExactBalanceToBalanceId = commandId(SEBTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, MINIMUM);
        emit Command(host, SEBTB, schema, swapExactBalanceToBalanceId, BALANCES, BALANCES);
    }

    // @dev implementation extracts the requested minimum from rawRoute.innerMinimum()
    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory out);

    function swapExactBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactBalanceToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, BALANCE_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            AssetAmount memory out = swapExactBalanceToBalance(c.account, balance, route);
            writer.appendNonZeroBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract SwapExactCustodyToBalance is CommandBase {
    uint internal immutable swapExactCustodyToBalanceId = commandId(SECTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, MINIMUM);
        emit Command(host, SECTB, schema, swapExactCustodyToBalanceId, CUSTODIES, BALANCES);
    }

    // @dev implementation extracts the requested minimum from rawRoute.innerMinimum()
    function swapExactCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory out);

    function swapExactCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactCustodyToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, CUSTODY_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            AssetAmount memory out = swapExactCustodyToBalance(c.account, custody, route);
            writer.appendNonZeroBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
