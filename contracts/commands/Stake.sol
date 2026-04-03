// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Blocks, Cursor, Writers, Writer, Keys } from "../Blocks.sol";

string constant SBTB = "stakeBalanceToBalances";
string constant SCTB = "stakeCustodyToBalances";
string constant SCTP = "stakeCustodyToPosition";

using Blocks for Cursor;
using Writers for Writer;

abstract contract StakeBalanceToBalances is CommandBase {
    uint internal immutable stakeBalanceToBalancesId = commandId(SBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SBTB, input, stakeBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to stake a balance position and append resulting balances
    /// to `out`. `input` is the request cursor for the current iteration;
    /// implementations validate and unpack it as needed and may append BALANCE
    /// outputs within the capacity implied by this command's configured
    /// `scaledRatio`.
    function stakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function stakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Blocks.matchingFrom(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            AssetAmount memory balance = balances.toBalanceValue();
            stakeBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}

abstract contract StakeCustodyToBalances is CommandBase {
    uint internal immutable stakeCustodyToBalancesId = commandId(SCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, SCTB, input, stakeCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to stake a custody position and append resulting balances
    /// to `out`. `input` is the request cursor for the current iteration;
    /// implementations validate and unpack it as needed and may append BALANCE
    /// outputs within the capacity implied by this command's configured
    /// `scaledRatio`.
    function stakeCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function stakeCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Blocks.matchingFrom(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            HostAmount memory custody = custodies.toCustodyValue();
            stakeCustodyToBalances(c.account, custody, input, writer);
        }

        return writer.finish();
    }
}

abstract contract StakeCustodyToPosition is CommandBase {
    uint internal immutable stakeCustodyToPositionId = commandId(SCTP);

    constructor(string memory input) {
        emit Command(host, SCTP, input, stakeCustodyToPositionId, Channels.Custodies, Channels.Setup);
    }

    /// @dev Override to stake a custody position into a non-balance setup
    /// target described by `input`.
    function stakeCustodyToPosition(bytes32 account, HostAmount memory custody, Cursor memory input) internal virtual;

    function stakeCustodyToPosition(
        CommandContext calldata c
    ) external payable onlyCommand(stakeCustodyToPositionId, c.target) returns (bytes memory) {
        (Cursor memory custodies, ) = Blocks.matchingFrom(c.state, 0, Keys.Custody);
        Cursor memory input;
        while (custodies.i < custodies.end) {
            HostAmount memory custody = custodies.toCustodyValue();
            input = Blocks.cursorFrom(c.request, input.cursor);
            stakeCustodyToPosition(c.account, custody, input);
        }

        return done(custodies);
    }
}
