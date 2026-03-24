// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES, CUSTODIES} from "../utils/Channels.sol";
import {AssetAmount, HostAmount, AMOUNT, BALANCE_KEY, CUSTODY_KEY, Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";
import {routeSchema1} from "../utils/Utils.sol";

string constant BABTB = "borrowAgainstBalanceToBalance";
string constant BACTB = "borrowAgainstCustodyToBalance";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract BorrowAgainstCustodyToBalance is CommandBase {
    uint internal immutable borrowAgainstCustodyToBalanceId = commandId(BACTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, AMOUNT);
        emit Command(host, BACTB, schema, borrowAgainstCustodyToBalanceId, CUSTODIES, BALANCES);
    }

    // @dev implementation extracts the requested borrow amount from rawRoute.innerAmount()
    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstCustodyToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, CUSTODY_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue(c.state);
            AssetAmount memory out = borrowAgainstCustodyToBalance(c.account, custody, route);
            writer.appendNonZeroBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}

abstract contract BorrowAgainstBalanceToBalance is CommandBase {
    uint internal immutable borrowAgainstBalanceToBalanceId = commandId(BABTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, AMOUNT);
        emit Command(host, BABTB, schema, borrowAgainstBalanceToBalanceId, BALANCES, BALANCES);
    }

    // @dev implementation extracts the requested borrow amount from rawRoute.innerAmount()
    function borrowAgainstBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstBalanceToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, BALANCE_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            AssetAmount memory out = borrowAgainstBalanceToBalance(c.account, balance, route);
            writer.appendNonZeroBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
