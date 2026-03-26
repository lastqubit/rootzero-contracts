// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, CUSTODIES } from "../utils/Channels.sol";
import { AssetAmount, HostAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

string constant RDBTB = "redeemFromBalanceToBalances";
string constant RDCTB = "redeemFromCustodyToBalances";

using Blocks for Block;
using Writers for Writer;

abstract contract RedeemFromBalanceToBalances is CommandBase {
    uint internal immutable redeemFromBalanceToBalancesId = commandId(RDBTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, RDBTB, maybeRoute, redeemFromBalanceToBalancesId, BALANCES, BALANCES);
    }

    /// @dev Override to redeem a balance position into balances.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append one or more BALANCE
    /// blocks to `out`.
    function redeemFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function redeemFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromBalanceToBalancesId, c.target) returns (bytes memory) {
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
            redeemFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract RedeemFromCustodyToBalances is CommandBase {
    uint internal immutable redeemFromCustodyToBalancesId = commandId(RDCTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, RDCTB, maybeRoute, redeemFromCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    /// @dev Override to redeem a custody position into balances.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append one or more BALANCE
    /// blocks to `out`.
    function redeemFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function redeemFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromCustodyToBalancesId, c.target) returns (bytes memory) {
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
            redeemFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
