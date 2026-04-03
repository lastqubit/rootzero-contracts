// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Blocks, Cursor, Writers, Writer, Keys } from "../Blocks.sol";

string constant BABTB = "borrowAgainstBalanceToBalance";
string constant BACTB = "borrowAgainstCustodyToBalance";

using Blocks for Cursor;
using Writers for Writer;

abstract contract BorrowAgainstCustodyToBalance is CommandBase {
    uint internal immutable borrowAgainstCustodyToBalanceId = commandId(BACTB);

    constructor(string memory input) {
        emit Command(host, BACTB, input, borrowAgainstCustodyToBalanceId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to borrow against a custody position.
    /// `input` is the request cursor for the current iteration; implementations
    /// validate and unpack it as needed.
    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstCustodyToBalanceId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Blocks.matchingFrom(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocBalances(count);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            HostAmount memory custody = custodies.toCustodyValue();
            AssetAmount memory out = borrowAgainstCustodyToBalance(c.account, custody, input);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}

abstract contract BorrowAgainstBalanceToBalance is CommandBase {
    uint internal immutable borrowAgainstBalanceToBalanceId = commandId(BABTB);

    constructor(string memory input) {
        emit Command(host, BABTB, input, borrowAgainstBalanceToBalanceId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to borrow against a balance position.
    /// `input` is the request cursor for the current iteration; implementations
    /// validate and unpack it as needed.
    function borrowAgainstBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstBalanceToBalanceId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Blocks.matchingFrom(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocBalances(count);
        Cursor memory input;

        while (balances.i < balances.end) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            AssetAmount memory balance = balances.toBalanceValue();
            AssetAmount memory out = borrowAgainstBalanceToBalance(c.account, balance, input);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}
