// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Cursors, Cursor, Writers, Writer, Keys } from "../Cursors.sol";

string constant RDBTB = "redeemFromBalanceToBalances";
string constant RDCTB = "redeemFromCustodyToBalances";

using Cursors for Cursor;
using Writers for Writer;

abstract contract RedeemFromBalanceToBalances is CommandBase {
    uint internal immutable redeemFromBalanceToBalancesId = commandId(RDBTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RDBTB, maybeInput, redeemFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to redeem a balance position into balances.
    /// `input` is zero-initialized and should be ignored when
    /// `maybeInput` is empty. Implementations validate and unpack it as
    /// needed, and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function redeemFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function redeemFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Cursors.openKeyed(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            if (useInput) {
                input = Cursors.openBlock(c.request, input.next);
            }
            AssetAmount memory balance = balances.unpackBalanceValue();
            redeemFromBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}

abstract contract RedeemFromCustodyToBalances is CommandBase {
    uint internal immutable redeemFromCustodyToBalancesId = commandId(RDCTB);
    uint private immutable outScale;
    bool private immutable useInput;

    constructor(string memory maybeInput, uint scaledRatio) {
        outScale = scaledRatio;
        useInput = bytes(maybeInput).length > 0;
        emit Command(host, RDCTB, maybeInput, redeemFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to redeem a custody position into balances.
    /// `input` is zero-initialized and should be ignored when
    /// `maybeInput` is empty. Implementations validate and unpack it as
    /// needed, and may append BALANCE outputs to `out` within the capacity
    /// implied by this command's configured `scaledRatio`.
    function redeemFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function redeemFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory custodies, uint count) = Cursors.openKeyed(c.state, 0, Keys.Custody);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (custodies.i < custodies.end) {
            if (useInput) {
                input = Cursors.openBlock(c.request, input.next);
            }
            HostAmount memory custody = custodies.unpackCustodyValue();
            redeemFromCustodyToBalances(c.account, custody, input, writer);
        }

        return writer.finish();
    }
}





