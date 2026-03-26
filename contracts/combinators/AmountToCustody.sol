// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AMOUNT_KEY, HostAmount} from "../Schema.sol";
import {Data, DataRef, Writers, Writer} from "../Blocks.sol";

using Data for DataRef;
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
            DataRef memory ref = Data.from(blocks, i);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount();
            HostAmount memory out = amountToCustody(host, account, asset, meta, amount);
            if (out.amount > 0) writer.appendCustody(out);
            i = ref.cursor;
        }

        return writer.finish();
    }
}
