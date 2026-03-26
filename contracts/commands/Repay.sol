// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, CUSTODIES } from "../utils/Channels.sol";
import { AssetAmount, HostAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";
import { Schemas } from "../blocks/Schema.sol";

string constant RFBTB = "repayFromBalanceToBalances";
string constant RFCTB = "repayFromCustodyToBalances";

using Blocks for Block;
using Writers for Writer;

abstract contract RepayFromBalanceToBalances is CommandBase {
    uint internal immutable repayFromBalanceToBalancesId = commandId(RFBTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, RFBTB, maybeRoute, repayFromBalanceToBalancesId, BALANCES, BALANCES);
    }

    /// @dev Override to repay debt using a balance amount.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append returned balances to
    /// `out`.
    function repayFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function repayFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromBalanceToBalancesId, c.target) returns (bytes memory) {
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
            repayFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract RepayFromCustodyToBalances is CommandBase {
    uint internal immutable repayFromCustodyToBalancesId = commandId(RFCTB);
    uint private immutable outScale;
    bool private immutable useRoute;

    constructor(string memory maybeRoute, uint scaledRatio) {
        outScale = scaledRatio;
        useRoute = bytes(maybeRoute).length > 0;
        emit Command(host, RFCTB, maybeRoute, repayFromCustodyToBalancesId, CUSTODIES, BALANCES);
    }

    /// @dev Override to repay debt using a custody amount.
    /// `rawRoute` is zero-initialized and should be ignored when
    /// `maybeRoute` is empty. Implementations may append returned balances to
    /// `out`.
    function repayFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute,
        Writer memory out
    ) internal virtual;

    function repayFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromCustodyToBalancesId, c.target) returns (bytes memory) {
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
            repayFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
