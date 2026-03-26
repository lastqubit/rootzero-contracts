// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, CUSTODIES } from "../utils/Channels.sol";
import { AssetAmount, HostAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

string constant LFBTB = "liquidateFromBalanceToBalances";
string constant LFCTB = "liquidateFromCustodyToBalances";

using Blocks for Block;
using Writers for Writer;

abstract contract LiquidateFromBalanceToBalances is CommandBase {
    uint internal immutable liquidateFromBalanceToBalancesId = commandId(LFBTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, LFBTB, maybeRoute, liquidateFromBalanceToBalancesId, BALANCES, BALANCES);
    }

    /// @dev Override to liquidate using a balance repayment amount.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append returned balances to
    /// `out`.
    function liquidateFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function liquidateFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Balance, outScale);

        while (i < end) {
            Block memory route;
            if (useRoute) {
                route = Blocks.routeFrom(c.request, q);
                q = route.cursor;
            }
            Block memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue();
            liquidateFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract LiquidateFromCustodyToBalances is CommandBase {
    uint internal immutable liquidateFromCustodyToBalancesId = commandId(LFCTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, LFCTB, maybeRoute, liquidateFromCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    /// @dev Override to liquidate using a custody repayment amount.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append returned balances to
    /// `out`.
    function liquidateFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function liquidateFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, Keys.Custody, outScale);

        while (i < end) {
            Block memory route;
            if (useRoute) {
                route = Blocks.routeFrom(c.request, q);
                q = route.cursor;
            }
            Block memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue();
            liquidateFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
