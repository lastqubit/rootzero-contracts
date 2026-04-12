// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers } from "../Cursors.sol";

string constant RFBTB = "repayFromBalanceToBalances";
string constant RFCTB = "repayFromCustodyToBalances";

using Cursors for Cur;
using Writers for Writer;

/// @title RepayFromBalanceToBalances
/// @notice Command that repays debt using BALANCE state blocks and emits BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract RepayFromBalanceToBalances is CommandBase {
    uint internal immutable repayFromBalanceToBalancesId = commandId(RFBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RFBTB, input, repayFromBalanceToBalancesId, State.Balances, State.Balances);
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
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            repayFromBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title RepayFromCustodyToBalances
/// @notice Command that repays debt using CUSTODY state blocks and emits BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract RepayFromCustodyToBalances is CommandBase {
    uint internal immutable repayFromCustodyToBalancesId = commandId(RFCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RFCTB, input, repayFromCustodyToBalancesId, State.Custodies, State.Balances);
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
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            repayFromCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}







