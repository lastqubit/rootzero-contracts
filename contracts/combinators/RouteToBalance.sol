// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cursors, Cur, Writers, Writer} from "../Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract RouteToBalance {
    function routeToBalance(
        bytes32 account,
        Cur memory route
    ) internal virtual returns (bytes32 asset, bytes32 meta, uint amount);

    function routesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        Cur memory scan = Cursors.open(blocks[i:]);
        (, uint count) = scan.primeRun(1);
        Writer memory writer = Writers.allocBalances(count);

        while (scan.i < scan.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = routeToBalance(account, scan);
            if (amount > 0) writer.appendBalance(asset, meta, amount);
        }

        return writer.finish();
    }
}





