// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Channels } from "./Base.sol";
import { AssetAmount, Blocks, Cursor, Writers, Writer, Keys } from "../Blocks.sol";

string constant UBTB = "unstakeBalanceToBalances";

using Blocks for Cursor;
using Writers for Writer;

abstract contract UnstakeBalanceToBalances is CommandBase {
    uint internal immutable unstakeBalanceToBalancesId = commandId(UBTB);
    uint private immutable outScale;

    constructor(string memory input, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, UBTB, input, unstakeBalanceToBalancesId, Channels.Balances, Channels.Balances);
    }

    /// @dev Override to unstake or redeem a balance position.
    /// `input` is the request cursor for the current iteration;
    /// implementations validate and unpack it as needed, and may append
    /// BALANCE outputs to `out` within the capacity implied by this
    /// command's configured `scaledRatio`.
    function unstakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        Cursor memory input,
        Writer memory out
    ) internal virtual;

    function unstakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(unstakeBalanceToBalancesId, c.target) returns (bytes memory) {
        (Cursor memory balances, uint count) = Blocks.matchingFrom(c.state, 0, Keys.Balance);
        Writer memory writer = Writers.allocScaledBalances(count, outScale);
        Cursor memory input;

        while (balances.i < balances.end) {
            input = Blocks.cursorFrom(c.request, input.cursor);
            AssetAmount memory balance = balances.toBalanceValue();
            unstakeBalanceToBalances(c.account, balance, input, writer);
        }

        return writer.finish();
    }
}
