// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {ROUTE_KEY} from "../Schema.sol";
import {Data, DataRef} from "../Blocks.sol";

abstract contract EachRoute {
    function eachRoute(DataRef memory rawRoute) internal virtual;

    function forEachRoute(bytes calldata blocks, uint i) internal returns (uint) {
        while (i < blocks.length) {
            (DataRef memory ref, uint next) = Data.from(blocks, i);
            if (ref.key != ROUTE_KEY) return i;
            eachRoute(ref);
            i = next;
        }
        return i;
    }
}
