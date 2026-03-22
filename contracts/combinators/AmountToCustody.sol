// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AMOUNT_KEY, HostAmount} from "../Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract AmountToCustody {
    function amountToCustody(
        uint host,
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual returns (HostAmount memory);

    function amountsToCustodies(
        bytes calldata blocks,
        uint i,
        uint host,
        bytes32 account
    ) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(blocks, i, AMOUNT_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(blocks, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(blocks);
            HostAmount memory out = amountToCustody(host, account, asset, meta, amount);
            if (out.amount > 0) writer.appendCustody(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
