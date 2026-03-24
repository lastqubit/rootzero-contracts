// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AssetAmount, HostAmount, CUSTODY_KEY, ROUTE_KEY} from "../Schema.sol";
import {Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract CustodyToBalance {
    function custodyToBalance(bytes32 account, HostAmount memory custody) internal virtual returns (AssetAmount memory);

    function custodiesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, CUSTODY_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(blocks, i);
            HostAmount memory custody = ref.toCustodyValue(blocks);
            AssetAmount memory out = custodyToBalance(account, custody);
            writer.appendNonZeroBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
