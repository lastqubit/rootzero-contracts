// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

using Blocks for Block;
using Writers for Writer;

abstract contract AmountToBalance {
    function amountToBalance(bytes32 account, AssetAmount memory amount) internal virtual returns (AssetAmount memory);

    function amountsToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, Keys.Amount);

        while (i < end) {
            Block memory ref = Blocks.from(blocks, i);
            AssetAmount memory amount = ref.toAmountValue();
            AssetAmount memory out = amountToBalance(account, amount);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
