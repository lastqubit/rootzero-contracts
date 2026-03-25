// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CUSTODY_KEY, HostAmount} from "../Schema.sol";
import {Blocks, BlockRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

abstract contract MapCustody {
    function mapCustody(bytes32 account, HostAmount memory custody) internal virtual returns (HostAmount memory out);

    function mapCustodies(bytes calldata state, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(state, i, CUSTODY_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.from(state, i);
            HostAmount memory custody = ref.toCustodyValue(state);
            HostAmount memory out = mapCustody(account, custody);
            if (out.amount > 0) writer.appendCustody(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
