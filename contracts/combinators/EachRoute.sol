// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Blocks, Block, Keys } from "../Blocks.sol";

abstract contract EachRoute {
    function eachRoute(Block memory rawRoute) internal virtual;

    function forEachRoute(bytes calldata blocks, uint i) internal returns (uint) {
        while (i < blocks.length) {
            Block memory ref = Blocks.from(blocks, i);
            if (ref.key != Keys.Route) return i;
            eachRoute(ref);
            i = ref.cursor;
        }
        return i;
    }
}
