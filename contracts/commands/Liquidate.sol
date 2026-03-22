// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, BALANCES, CUSTODIES} from "./Base.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, Data, DataRef, Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

string constant LFBTB = "liquidateFromBalanceToBalances";
string constant LFCTB = "liquidateFromCustodyToBalances";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract LiquidateFromBalanceToBalances is CommandBase {
    uint internal immutable liquidateFromBalanceToBalancesId = commandId(LFBTB);
    uint internal immutable lfbtbOutScale;
    bool private immutable useRouteLfbtb;

    constructor(string memory maybeRoute, uint scaledRatio) {
        lfbtbOutScale = scaledRatio;
        useRouteLfbtb = bytes(maybeRoute).length > 0;
        emit Command(host, LFBTB, maybeRoute, liquidateFromBalanceToBalancesId, BALANCES, BALANCES);
    }

    // @dev `balance` is the offered liquidation repayment amount and may leave a returned remainder.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function liquidateFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function liquidateFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, lfbtbOutScale);

        while (i < end) {
            DataRef memory route;
            if (useRouteLfbtb) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            liquidateFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract LiquidateFromCustodyToBalances is CommandBase {
    uint internal immutable liquidateFromCustodyToBalancesId = commandId(LFCTB);
    uint internal immutable lfctbOutScale;
    bool private immutable useRouteLfctb;

    constructor(string memory maybeRoute, uint scaledRatio) {
        lfctbOutScale = scaledRatio;
        useRouteLfctb = bytes(maybeRoute).length > 0;
        emit Command(host, LFCTB, maybeRoute, liquidateFromCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    // @dev `custody` is the offered liquidation repayment amount and may leave a returned remainder.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function liquidateFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function liquidateFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, lfctbOutScale);

        while (i < end) {
            DataRef memory route;
            if (useRouteLfctb) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            liquidateFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}
