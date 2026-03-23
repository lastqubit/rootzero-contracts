// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, Data, DataRef, Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

string constant RDBTB = "redeemFromBalanceToBalances";
string constant RDCTB = "redeemFromCustodyToBalances";

using Blocks for BlockRef;
using Data for DataRef;
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

    // @dev `balance` is the redeemable claim/share/position amount offered for redemption.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function redeemFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function redeemFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            if (useRoute) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            redeemFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
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

    // @dev `custody` is the redeemable claim/share/position amount offered for redemption.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function redeemFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function redeemFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            if (useRoute) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            redeemFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}
