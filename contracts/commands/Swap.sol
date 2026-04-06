// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, Cursors, Cursor, HostAmount, Keys, Writer, Writers } from "../Cursors.sol";
using Cursors for Cursor;
using Writers for Writer;

string constant SEBTB = "swapExactBalanceToBalance";
string constant SECTB = "swapExactCustodyToBalance";

abstract contract SwapExactBalanceToBalance is CommandBase {
    uint internal immutable swapExactBalanceToBalanceId = commandId(SEBTB);

    constructor(string memory input) {
        emit Command(host, SEBTB, input, swapExactBalanceToBalanceId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to swap an exact balance input into a balance output.
    /// `input` is the request cursor for the current iteration; implementations
    /// validate and unpack it as needed.
    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input
    ) internal virtual returns (AssetAmount memory out);

    function swapExactBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactBalanceToBalanceId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocBalances(count);
        Cursor memory input;

        while (balances.i < balances.end) {
            input = Cursors.openFrom(c.request, input.next);
            AssetAmount memory balance = balances.unpackBalanceValue();
            AssetAmount memory out = swapExactBalanceToBalance(c.account, balance, input);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}

abstract contract SwapExactCustodyToBalance is CommandBase {
    uint internal immutable swapExactCustodyToBalanceId = commandId(SECTB);

    constructor(string memory input) {
        emit Command(host, SECTB, input, swapExactCustodyToBalanceId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to swap an exact custody input into a balance output.
    /// `input` is the request cursor for the current iteration; implementations
    /// validate and unpack it as needed.
    function swapExactCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input
    ) internal virtual returns (AssetAmount memory out);

    function swapExactCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactCustodyToBalanceId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocBalances(count);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            input = Cursors.openFrom(c.request, input.next);
            HostAmount memory custody = custodies.unpackCustodyValue();
            AssetAmount memory out = swapExactCustodyToBalance(c.account, custody, input);
            writer.appendNonZeroBalance(out);
        }

        return writer.finish();
    }
}




