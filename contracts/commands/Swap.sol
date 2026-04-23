// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase, State} from "./Base.sol";
import {Cursors, Cur, Writer, Writers, Schemas, AssetAmount} from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

string constant NAME = "swap";

abstract contract SwapHook {
    function swap(
        AssetAmount memory from,
        Cur memory path,
        Cur memory route
    ) internal virtual returns (AssetAmount memory);
}

abstract contract Swap is CommandBase, SwapHook {
    uint internal immutable swapId = commandId(NAME);

    constructor(string memory item, string memory maybeRoute) {
        string memory input = string.concat(maybeRoute, "& path[] = ", item);
        emit Command(host, NAME, input, swapId, State.Balances, State.Balances, false);
    }

    function swap(CommandContext calldata c) external onlyCommand(c.account) returns (bytes memory) {
        (Cur memory state, uint count, uint quotient) = cursor(c.state, 1);
        Cur memory input = cursor(c.request, 1, quotient);
        Writer memory writer = Writers.allocBalances(count);

        while (state.i < state.bound) {
            AssetAmount memory balance = state.unpackBalanceValue();
            uint next = input.bundle();
            balance = swap(balance, input.maybeRoute(), input);
            writer.appendBalance(balance);
            input.ensure(next);
        }

        return state.complete(writer);
    }
}
