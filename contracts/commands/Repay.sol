// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers, Writers2 } from "../Cursors.sol";

string constant RFBTB = "repayFromBalanceToBalances";
string constant RFCTB = "repayFromCustodyToBalances";

using Cursors for Cur;
using Writers for Writer;
using Writers2 for Cur;

abstract contract RepayFromBalanceToBalances is CommandBase {
    uint internal immutable repayFromBalanceToBalancesId = commandId(RFBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RFBTB, input, repayFromBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to repay debt using a balance amount.
    /// `request` is the live auxiliary request cursor for this command.
    /// Implementations may consume it as needed or ignore it, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function repayFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function repayFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocScaledBalances(outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            repayFromBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}

abstract contract RepayFromCustodyToBalances is CommandBase {
    uint internal immutable repayFromCustodyToBalancesId = commandId(RFCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RFCTB, input, repayFromCustodyToBalancesId, Channels.Custodies, Channels.Balances);
    }

    /// @dev Override to repay debt using a custody amount.
    /// `request` is the live auxiliary request cursor for this command.
    /// Implementations may consume it as needed or ignore it, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function repayFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function repayFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(repayFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, Cur memory request) = cursors(c, 1, 0);
        Writer memory writer = state.allocScaledBalances(outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            repayFromCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}







