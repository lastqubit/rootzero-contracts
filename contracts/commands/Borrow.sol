// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers, Writers2 } from "../Cursors.sol";

string constant BABTB = "borrowAgainstBalanceToBalance";
string constant BACTB = "borrowAgainstCustodyToBalance";

using Cursors for Cur;
using Writers for Writer;
using Writers2 for Cur;

abstract contract BorrowAgainstCustodyToBalance is CommandBase {
    uint internal immutable borrowAgainstCustodyToBalanceId = commandId(BACTB);

    constructor(string memory input) {
        emit Command(host, BACTB, input, borrowAgainstCustodyToBalanceId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to borrow against a custody position.
    /// `request` is the live auxiliary request cursor for this command;
    /// implementations validate and unpack it as needed.
    function borrowAgainstCustodyToBalance(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstCustodyToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstCustodyToBalanceId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocBalances();

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            AssetAmount memory out = borrowAgainstCustodyToBalance(c.account, custody, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}

abstract contract BorrowAgainstBalanceToBalance is CommandBase {
    uint internal immutable borrowAgainstBalanceToBalanceId = commandId(BABTB);

    constructor(string memory input) {
        emit Command(host, BABTB, input, borrowAgainstBalanceToBalanceId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to borrow against a balance position.
    /// `request` is the live auxiliary request cursor for this command;
    /// implementations validate and unpack it as needed.
    function borrowAgainstBalanceToBalance(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request
    ) internal virtual returns (AssetAmount memory);

    function borrowAgainstBalanceToBalance(
        CommandContext calldata c
    ) external payable onlyCommand(borrowAgainstBalanceToBalanceId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocBalances();

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            AssetAmount memory out = borrowAgainstBalanceToBalance(c.account, balance, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}







