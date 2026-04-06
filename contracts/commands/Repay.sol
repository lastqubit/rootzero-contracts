// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Cursors, Cursor, Writers, Writer, Keys } from "../Cursors.sol";

string constant RFBTB = "repayFromBalanceToBalances";
string constant RFCTB = "repayFromCustodyToBalances";

using Cursors for Cursor;
using Writers for Writer;

abstract contract RepayFromBalanceToBalances is CommandBase {
    uint internal immutable repayFromBalanceToBalancesId = commandId(RFBTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RFBTB, maybeInput, repayFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to repay debt using a balance amount.
    /// `input` is zero-initialized and should be ignored when
    /// `maybeInput` is empty. Implementations validate and unpack it as
    /// needed, and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function repayFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function repayFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            AssetAmount memory balance = balances.unpackBalanceValue();
            repayFromBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}

abstract contract RepayFromCustodyToBalances is CommandBase {
    uint internal immutable repayFromCustodyToBalancesId = commandId(RFCTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RFCTB, maybeInput, repayFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to repay debt using a custody amount.
    /// `input` is zero-initialized and should be ignored when
    /// `maybeInput` is empty. Implementations validate and unpack it as
    /// needed, and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function repayFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function repayFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            if (useInput) {
                input = Cursors.openFrom(c.request, input.next);
            }
            HostAmount memory custody = custodies.unpackCustodyValue();
            repayFromCustodyToBalances(c.account, custody, input, writer);
        }

        return writer.finish();
    }
}




