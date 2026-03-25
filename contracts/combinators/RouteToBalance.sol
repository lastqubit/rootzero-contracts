// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {ROUTE_KEY} from "../Schema.sol";
import {Data, DataRef, Writers, Writer} from "../Blocks.sol";

using Writers for Writer;

abstract contract RouteToBalance {
    function routeToBalance(
        bytes32 account,
        DataRef memory rawRoute
    ) internal virtual returns (bytes32 asset, bytes32 meta, uint amount);

    function routesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, ROUTE_KEY);

        while (i < end) {
            DataRef memory route;
            (route, i) = Data.routeFrom(blocks, i);
            (bytes32 asset, bytes32 meta, uint amount) = routeToBalance(account, route);
            if (amount > 0) writer.appendBalance(asset, meta, amount);
        }

        return writer.finish();
    }
}
