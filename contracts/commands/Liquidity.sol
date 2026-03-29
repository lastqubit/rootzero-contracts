// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

using Blocks for Block;
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
        string memory schema = Schemas.route1(maybeRoute, Schemas.Minimum);
        emit Command(host, ALFCTB, schema, addLiquidityFromCustodiesToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to add liquidity from two custody inputs.
    /// Implementations extract the requested minimum liquidity output from
    /// `rawRoute.innerMinimum()` and may append up to three BALANCE blocks to
    /// `out`: two refunds plus the liquidity receipt.
    function addLiquidityFromCustodiesToBalances(
        bytes32 account,
        Block memory custodiesView,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromCustodiesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromCustodiesToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Custody, outScale);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory custodies = Blocks.viewFrom(c.state, i, 2);
            i = custodies.cursor;
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
        string memory schema = Schemas.route2(maybeRoute, Schemas.Minimum, Schemas.Minimum);
        emit Command(host, RLFCTB, schema, removeLiquidityFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to remove liquidity from a custody position.
    /// Implementations extract requested minimum outputs from `rawRoute` and
    /// may append up to two BALANCE blocks to `out`.
    function removeLiquidityFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Custody, outScale);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue();
            removeLiquidityFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract AddLiquidityFromBalancesToBalances is CommandBase {
    uint internal immutable addLiquidityFromBalancesToBalancesId = commandId(ALFBTB);
    uint private immutable outScale;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        string memory schema = Schemas.route1(maybeRoute, Schemas.Minimum);
        emit Command(host, ALFBTB, schema, addLiquidityFromBalancesToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to add liquidity from two balance inputs.
    /// Implementations extract the requested minimum liquidity output from
    /// `rawRoute.innerMinimum()` and may append up to three BALANCE blocks to
    /// `out`: two refunds plus the liquidity receipt.
    function addLiquidityFromBalancesToBalances(
        bytes32 account,
        Block memory balancesView,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function addLiquidityFromBalancesToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(addLiquidityFromBalancesToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Balance, outScale);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory balances = Blocks.viewFrom(c.state, i, 2);
            i = balances.cursor;
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
        string memory schema = Schemas.route2(maybeRoute, Schemas.Minimum, Schemas.Minimum);
        emit Command(host, RLFBTB, schema, removeLiquidityFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to remove liquidity from a balance position.
    /// Implementations extract requested minimum outputs from `rawRoute` and
    /// may append up to two BALANCE blocks to `out`.
    function removeLiquidityFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function removeLiquidityFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(removeLiquidityFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Balance, outScale);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue();
            removeLiquidityFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
