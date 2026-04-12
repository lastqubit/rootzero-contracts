// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { AssetAmount, Cur, Cursors, Writer, Writers } from "../Cursors.sol";

string constant UBTB = "unstakeBalanceToBalances";

using Cursors for Cur;
using Writers for Writer;

/// @title UnstakeBalanceToBalances
/// @notice Command that unstakes BALANCE state positions and emits BALANCE outputs.
/// The output-to-input ratio is set at construction via `scaledRatio`.
abstract contract UnstakeBalanceToBalances is CommandBase {
    uint internal immutable unstakeBalanceToBalancesId = commandId(UBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, UBTB, input, unstakeBalanceToBalancesId, State.Balances, State.Balances);
    }

    /// @dev Override to unstake or redeem a balance position.
    /// `request` is the live auxiliary request cursor for this command;
    /// implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this
    /// command's configured `scaledRatio`.
    function unstakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cur memory request,
        Writer memory out
    ) internal virtual;

    function unstakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(unstakeBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cur memory state, uint stateCount, ) = cursor(c.state, 1);
        Cur memory request = cursor(c.request);
        Writer memory writer = Writers.allocScaledBalances(stateCount, outScale);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            unstakeBalanceToBalances(c.account, balance, request, writer);
        }

        return state.complete(writer);
    }
}







