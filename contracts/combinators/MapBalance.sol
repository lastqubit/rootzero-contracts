// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

using Blocks for Block;
using Writers for Writer;

abstract contract MapBalance {
    function mapBalance(bytes32 account, AssetAmount memory balance) internal virtual returns (AssetAmount memory out);

    function mapBalances(bytes calldata state, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(state, i, Keys.Balance);

        while (i < end) {
            Block memory ref = Blocks.from(state, i);
            AssetAmount memory balance = ref.toBalanceValue();
            AssetAmount memory out = mapBalance(account, balance);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
