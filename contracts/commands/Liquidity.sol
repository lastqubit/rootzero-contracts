// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, MINIMUM, DataPairRef} from "../blocks/Schema.sol";
import {BlockRef, Blocks, Data, DataRef, Writers, Writer} from "../Blocks.sol";
import {routeSchema1, routeSchema2} from "../utils/Utils.sol";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

string constant ALFCTB = "addLiquidityFromCustodiesToBalances";
string constant ALFBTB = "addLiquidityFromBalancesToBalances";
string constant RLFCTB = "removeLiquidityFromCustodyToBalances";
string constant RLFBTB = "removeLiquidityFromBalanceToBalances";

abstract contract AddLiquidityFromCustodiesToBalances is CommandBase {
    uint internal immutable addLiquidityFromCustodiesToBalancesId = commandId(ALFCTB);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = routeSchema1(maybeRoute, MINIMUM);
        emit Command(host, ALFCTB, schema, addLiquidityFromCustodiesToBalancesId, CUSTODIES, BALANCES);
    }

    // @dev implementation extracts the requested minimum liquidity output from rawRoute.innerMinimum()
    // and may append up to three balances per custody pair: two refunds plus the liquidity receipt.
    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        DataPairRef memory rawCustodies,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromCustodiesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromCustodiesToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            DataPairRef memory custodies;
            (custodies, i) = Data.twoFrom(c.state, i);
            addLiquidityFromCustodiesToBalances(c.account, custodies, route, writer);
        }

        return writer.finish();
    }
}

abstract contract RemoveLiquidityFromCustodyToBalances is CommandBase {
    uint internal immutable removeLiquidityFromCustodyToBalancesId = commandId(RLFCTB);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = routeSchema2(maybeRoute, MINIMUM, MINIMUM);
        emit Command(host, RLFCTB, schema, removeLiquidityFromCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    // @dev implementation extracts requested minimum outputs from rawRoute and
    // may append up to two balances per custody input when removing liquidity.
    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            removeLiquidityFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract AddLiquidityFromBalancesToBalances is CommandBase {
    uint internal immutable addLiquidityFromBalancesToBalancesId = commandId(ALFBTB);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = routeSchema1(maybeRoute, MINIMUM);
        emit Command(host, ALFBTB, schema, addLiquidityFromBalancesToBalancesId, BALANCES, BALANCES);
    }

    // @dev implementation extracts the requested minimum liquidity output from rawRoute.innerMinimum()
    // and may append up to three balances per balance pair: two refunds plus the liquidity receipt.
    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        DataPairRef memory rawBalances,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromBalancesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromBalancesToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            DataPairRef memory balances;
            (balances, i) = Data.twoFrom(c.state, i);
            addLiquidityFromBalancesToBalances(c.account, balances, route, writer);
        }

        return writer.finish();
    }
}

abstract contract RemoveLiquidityFromBalanceToBalances is CommandBase {
    uint internal immutable removeLiquidityFromBalanceToBalancesId = commandId(RLFBTB);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = routeSchema2(maybeRoute, MINIMUM, MINIMUM);
        emit Command(host, RLFBTB, schema, removeLiquidityFromBalanceToBalancesId, BALANCES, BALANCES);
    }

    // @dev implementation extracts requested minimum outputs from rawRoute and
    // may append up to two balances per balance input when removing liquidity.
    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            removeLiquidityFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}
