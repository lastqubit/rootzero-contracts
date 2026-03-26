// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { Channels } from "../utils/Channels.sol";
import { AssetAmount, HostAmount } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Schemas } from "../blocks/Schema.sol";
import { Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";
import { routeSchema1 } from "../utils/Utils.sol";
using Blocks for Block;
using Writers for Writer;

string constant SEBTB = "swapExactBalanceToBalance";
string constant SECTB = "swapExactCustodyToBalance";

abstract contract SwapExactBalanceToBalance is CommandBase {
    uint internal immutable swapExactBalanceToBalanceId = commandId(SEBTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, Schemas.Minimum);
        emit Command(host, SEBTB, schema, swapExactBalanceToBalanceId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to swap an exact balance input into a balance output.
    /// Implementations extract the requested minimum from
    /// `rawRoute.innerMinimum()`.
    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute
    ) internal virtual returns (AssetAmount memory out);

    function swapExactBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactBalanceToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, Keys.Balance);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue();
            AssetAmount memory out = swapExactBalanceToBalance(c.account, balance, route);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract SwapExactCustodyToBalance is CommandBase {
    uint internal immutable swapExactCustodyToBalanceId = commandId(SECTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, Schemas.Minimum);
        emit Command(host, SECTB, schema, swapExactCustodyToBalanceId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to swap an exact custody input into a balance output.
    /// Implementations extract the requested minimum from
    /// `rawRoute.innerMinimum()`.
    function swapExactCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute
    ) internal virtual returns (AssetAmount memory out);

    function swapExactCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactCustodyToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, Keys.Custody);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue();
            AssetAmount memory out = swapExactCustodyToBalance(c.account, custody, route);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
