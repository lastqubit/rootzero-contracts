// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, BALANCE_KEY, CUSTODY_KEY, ROUTE_EMPTY, Data, DataRef, Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

string constant RFBTB = "repayFromBalanceToBalances";
string constant RFCTB = "repayFromCustodyToBalances";

using Blocks for BlockRef;
using Data for DataRef;
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

    // @dev `balance` is the offered repayment amount and may leave a returned remainder.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function repayFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function repayFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            if (useRoute) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            repayFromBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
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

    // @dev `custody` is the offered repayment amount and may leave a returned remainder.
    // `rawRoute` is zero-initialized and should be ignored when `maybeRoute` is empty.
    function repayFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function repayFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromCustodyToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, CUSTODY_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            if (useRoute) (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            repayFromCustodyToBalances(c.account, custody, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}
