// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, State} from "./Base.sol";
import {AssetAmount, HostAmount, Cur, Cursors, Writers, Writer} from "../Cursors.sol";

string constant LFBTB = "liquidateFromBalanceToBalances";
string constant LFCTB = "liquidateFromCustodyToBalances";

using Cursors for Cur;
using Writers for Writer;

/// @title LiquidateFromBalanceToBalances
/// @notice Command that liquidates BALANCE state positions into BALANCE outputs
/// using a virtual hook. The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract LiquidateFromBalanceToBalances is CommandBase {
    uint internal immutable liquidateFromBalanceToBalancesId = commandId(LFBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, LFBTB, input, liquidateFromBalanceToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to liquidate using a balance repayment amount.
    /// `request` may be ignored by implementations that don't need it.
    /// Implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function liquidateFromBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function liquidateFromBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            liquidateFromBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}

/// @title LiquidateFromCustodyToBalances
/// @notice Command that liquidates CUSTODY state positions into BALANCE outputs
/// using a virtual hook. The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract LiquidateFromCustodyToBalances is CommandBase {
    uint internal immutable liquidateFromCustodyToBalancesId = commandId(LFCTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, LFCTB, input, liquidateFromCustodyToBalancesId, State.Custodies, State.Balances);
    }

    /// @dev Override to liquidate using a custody repayment amount.
    /// `request` may be ignored by implementations that don't need it.
    /// Implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this command's
    /// configured `scaledRatio`.
    function liquidateFromCustodyToBalances(
        bytes32 account,
        HostAmount memory custody,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function liquidateFromCustodyToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(liquidateFromCustodyToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            HostAmount memory custody = state.unpackCustodyValue();
            liquidateFromCustodyToBalances(c.account, custody, request, writer);
        }

        return state.complete(writer);
    }
}







