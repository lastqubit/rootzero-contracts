// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandBase} from "./Base.sol";
import {BALANCES} from "../utils/Channels.sol";
import {AssetAmount, BALANCE_KEY, Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

string constant UBTB = "unstakeBalanceToBalances";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract UnstakeBalanceToBalances is CommandBase {
    uint internal immutable unstakeBalanceToBalancesId = commandId(UBTB);
    uint private immutable outScale;

    constructor(string memory route, uint scaledRatio) {
        outScale = scaledRatio;
        emit Command(host, UBTB, route, unstakeBalanceToBalancesId, BALANCES, BALANCES);
    }

    /// @dev Override to unstake or redeem a balance position.
    /// Implementations may append one or more BALANCE blocks to `out`.
    function unstakeBalanceToBalances(
        bytes32 account,
        AssetAmount memory balance,
        DataRef memory rawRoute,
        Writer memory out
    ) internal virtual;

    function unstakeBalanceToBalances(
        CommandContext calldata c
    ) external payable onlyCommand(unstakeBalanceToBalancesId, c.target) returns (bytes memory) {
        uint i = 0;
        uint q = 0;
        (Writer memory writer, uint end) = Writers.allocScaledBalancesFrom(c.state, i, BALANCE_KEY, outScale);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(c.request, q);
            BlockRef memory ref = Blocks.from(c.state, i);
            AssetAmount memory balance = ref.toBalanceValue(c.state);
            unstakeBalanceToBalances(c.account, balance, route, writer);
            i = ref.end;
        }

        return writer.finish();
    }
}
