// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cursors, Cursor, Keys } from "../Cursors.sol";

using Cursors for Cursor;

abstract contract EachRoute {
    function eachRoute(Cursor memory route) internal virtual;

    function forEachRoute(bytes calldata blocks, uint i) internal returns (uint) {
        Cursor memory routes = Cursors.openRun(blocks, i, Keys.Route, 1);
        while (routes.i < routes.end) {
            eachRoute(routes.take());
        }
        return routes.next;
    }
}





