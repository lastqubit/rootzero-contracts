// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, HostAmount, Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

using Blocks for Block;
using Writers for Writer;

abstract contract CustodyToBalance {
    function custodyToBalance(bytes32 account, HostAmount memory custody) internal virtual returns (AssetAmount memory);

    function custodiesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, Keys.Custody);

        while (i < end) {
            Block memory ref = Blocks.from(blocks, i);
            HostAmount memory custody = ref.toCustodyValue();
            AssetAmount memory out = custodyToBalance(account, custody);
            writer.appendNonZeroBalance(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
