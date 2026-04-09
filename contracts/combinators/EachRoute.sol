// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors, Cur } from "../Cursors.sol";

using Cursors for Cur;

abstract contract EachRoute {
    function eachRoute(Cur memory route) internal virtual;

    function forEachRoute(bytes calldata blocks, uint i) internal returns (uint) {
        (Cur memory routes, , ) = Cursors.init(blocks[i:], 1);
        if (routes.bound == 0) revert Cursors.ZeroCursor();

        while (routes.i < routes.bound) {
            eachRoute(routes);
        }
        return i + routes.bound;
    }
}






