// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, Cur, Cursors, HostAmount, Writer, Writers, Writers2 } from "../Cursors.sol";
using Cursors for Cur;
using Writers for Writer;
using Writers2 for Cur;

string constant SEBTB = "swapExactBalanceToBalance";
string constant SECTB = "swapExactCustodyToBalance";

abstract contract SwapExactBalanceToBalance is CommandBase {
    uint internal immutable swapExactBalanceToBalanceId = commandId(SEBTB);

    constructor(string memory input) {
        emit Command(host, SEBTB, input, swapExactBalanceToBalanceId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to swap an exact balance input into a balance output.
    /// `request` is the live auxiliary request cursor for this command;
    /// implementations validate and unpack it as needed.
    function swapExactBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request
    ) internal virtual returns (AssetAmount memory out);

    function swapExactBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactBalanceToBalanceId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocBalances();

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            AssetAmount memory out = swapExactBalanceToBalance(c.account, balance, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}

abstract contract SwapExactCustodyToBalance is CommandBase {
    uint internal immutable swapExactCustodyToBalanceId = commandId(SECTB);

    constructor(string memory input) {
        emit Command(host, SECTB, input, swapExactCustodyToBalanceId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to swap an exact custody input into a balance output.
    /// `request` is the live auxiliary request cursor for this command;
    /// implementations validate and unpack it as needed.
    function swapExactCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request
    ) internal virtual returns (AssetAmount memory out);

    function swapExactCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(swapExactCustodyToBalanceId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocBalances();

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            AssetAmount memory out = swapExactCustodyToBalance(c.account, custody, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}







