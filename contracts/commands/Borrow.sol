// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers } from "../Cursors.sol";

string constant BABTB = "borrowAgainstBalanceToBalance";
string constant BACTB = "borrowAgainstCustodyToBalance";

using Cursors for Cur;
using Writers for Writer;

/// @title BorrowAgainstCustodyToBalance
/// @notice Command that issues loans against CUSTODY state positions, emitting BALANCE outputs.
abstract contract BorrowAgainstCustodyToBalance is CommandBase {
    uint internal immutable borrowAgainstCustodyToBalanceId = commandId(BACTB);

    constructor(string memory input) {
        emit Command(host, BACTB, input, borrowAgainstCustodyToBalanceId, State.Custodies, State.Balances);
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
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocBalances(stateCount);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            AssetAmount memory out = borrowAgainstCustodyToBalance(c.account, custody, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}

/// @title BorrowAgainstBalanceToBalance
/// @notice Command that issues loans against BALANCE state positions, emitting BALANCE outputs.
abstract contract BorrowAgainstBalanceToBalance is CommandBase {
    uint internal immutable borrowAgainstBalanceToBalanceId = commandId(BABTB);

    constructor(string memory input) {
        emit Command(host, BABTB, input, borrowAgainstBalanceToBalanceId, State.Balances, State.Balances);
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
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocBalances(stateCount);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            AssetAmount memory out = borrowAgainstBalanceToBalance(c.account, balance, request);
            writer.appendNonZeroBalance(out);
        }

        return state.complete(writer);
    }
}







