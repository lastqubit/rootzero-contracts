// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, HostAmount, Cur, Cursors, Writer, Writers } from "../Cursors.sol";

string constant RDBTB = "redeemFromBalanceToBalances";
string constant RDCTB = "redeemFromCustodyToBalances";

using Cursors for Cur;
using Writers for Writer;

/// @title RedeemFromBalanceToBalances
/// @notice Command that redeems BALANCE state positions into BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract RedeemFromBalanceToBalances is CommandBase {
    uint internal immutable redeemFromBalanceToBalancesId = commandId(RDBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RDBTB, input, redeemFromBalanceToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to redeem a balance position into balances.
    /// `request` is the live auxiliary request cursor for this command.
    /// Implementations may consume it as needed or ignore it, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function redeemFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function redeemFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            redeemFromBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title RedeemFromCustodyToBalances
/// @notice Command that redeems CUSTODY state positions into BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract RedeemFromCustodyToBalances is CommandBase {
    uint internal immutable redeemFromCustodyToBalancesId = commandId(RDCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, RDCTB, input, redeemFromCustodyToBalancesId, State.Custodies, State.Balances);
    }

    /// @dev Override to redeem a custody position into balances.
    /// `request` is the live auxiliary request cursor for this command.
    /// Implementations may consume it as needed or ignore it, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function redeemFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function redeemFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(redeemFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            redeemFromCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}







