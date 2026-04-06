// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, Channels} from "./Base.sol";
import {AssetAmount, HostAmount, Cursors, Cursor, Writers, Writer, Keys} from "../Cursors.sol";

string constant LFBTB = "liquidateFromBalanceToBalances";
string constant LFCTB = "liquidateFromCustodyToBalances";

using Cursors for Cursor;
using Writers for Writer;

abstract contract LiquidateFromBalanceToBalances is CommandBase {
    uint internal immutable liquidateFromBalanceToBalancesId = commandId(LFBTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, LFBTB, maybeInput, liquidateFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to liquidate using a balance repayment amount.
    /// `input` is zero-initialized and should be ignored when `maybeInput` is
    /// empty. Implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function liquidateFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function liquidateFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            if (useInput) {
                input = Cursors.openBlock(c.request, input.next);
            }
            AssetAmount memory balance = balances.unpackBalanceValue();
            liquidateFromBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}

abstract contract LiquidateFromCustodyToBalances is CommandBase {
    uint internal immutable liquidateFromCustodyToBalancesId = commandId(LFCTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, LFCTB, maybeInput, liquidateFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to liquidate using a custody repayment amount.
    /// `input` is zero-initialized and should be ignored when `maybeInput` is
    /// empty. Implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function liquidateFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function liquidateFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            if (useInput) {
                input = Cursors.openBlock(c.request, input.next);
            }
            HostAmount memory custody = custodies.unpackCustodyValue();
            liquidateFromCustodyToBalances(c.account, custody, input, writer);
        }

        return writer.finish();
    }
}





