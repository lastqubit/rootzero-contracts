// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AMOUNT_KEY, AssetAmount} from "../Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract AmountToBalance {
    function amountToBalance(bytes32 account, AssetAmount memory amount) internal virtual returns (AssetAmount memory);

    function amountsToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(blocks, i);
            AssetAmount memory amount = ref.toAmountValue(blocks);
            AssetAmount memory out = amountToBalance(account, amount);
            if (out.amount > 0) writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
