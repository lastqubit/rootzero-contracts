// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase } from "./Base.sol";
import { BALANCES, CUSTODIES } from "../utils/Channels.sol";
import { AssetAmount, HostAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";
import { Schemas } from "../blocks/Schema.sol";
import { routeSchema1 } from "../utils/Utils.sol";

string constant BABTB = "borrowAgainstBalanceToBalance";
string constant BACTB = "borrowAgainstCustodyToBalance";

using Blocks for Block;
using Writers for Writer;

abstract contract BorrowAgainstCustodyToBalance is CommandBase {
    uint internal immutable borrowAgainstCustodyToBalanceId = commandId(BACTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, Schemas.Amount);
        emit Command(host, BACTB, schema, borrowAgainstCustodyToBalanceId, CUSTODIES, BALANCES);
    }

    /// @dev Override to borrow against a custody position.
    /// Implementations extract the requested borrow amount from
    /// `rawRoute.innerAmount()`.
    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Block memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstCustodyToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, Keys.Custody);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            HostAmount memory custody = ref.toCustodyValue();
            AssetAmount memory out = borrowAgainstCustodyToBalance(c.account, custody, route);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}

abstract contract BorrowAgainstBalanceToBalance is CommandBase {
    uint internal immutable borrowAgainstBalanceToBalanceId = commandId(BABTB);

    constructor(string memory maybeRoute) {
        string memory schema = routeSchema1(maybeRoute, Schemas.Amount);
        emit Command(host, BABTB, schema, borrowAgainstBalanceToBalanceId, BALANCES, BALANCES);
    }

    /// @dev Override to borrow against a balance position.
    /// Implementations extract the requested borrow amount from
    /// `rawRoute.innerAmount()`.
    function borrowAgainstBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Block memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstBalanceToBalanceId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.state, i, Keys.Balance);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(c.request, q);
            q = route.cursor;
            Block memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue();
            AssetAmount memory out = borrowAgainstBalanceToBalance(c.account, balance, route);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
