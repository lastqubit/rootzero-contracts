// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AssetAmount, BALANCE_KEY} from "../Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract MapBalance {
    function mapBalance(bytes32 account, AssetAmount memory balance) internal virtual returns (AssetAmount memory out);

    function mapBalances(bytes calldata state, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(state, i, BALANCE_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(state, i);
            AssetAmount memory balance = ref.toBalanceValue(state);
            AssetAmount memory out = mapBalance(account, balance);
            if (out.amount > 0) writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
