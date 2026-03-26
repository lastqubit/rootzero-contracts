// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Blocks, Block, Writers, Writer, Keys } from "../Blocks.sol";

using Writers for Writer;

abstract contract RouteToBalance {
    function routeToBalance(
        bytes32 account,
        Block memory rawRoute
    ) internal virtual returns (bytes32 asset, bytes32 meta, uint amount);

    function routesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, Keys.Route);

        while (i < end) {
            Block memory route;
            route = Blocks.routeFrom(blocks, i);
            i = route.cursor;
            (bytes32 asset, bytes32 meta, uint amount) = routeToBalance(account, route);
            if (amount > 0) writer.appendBalance(asset, meta, amount);
        }

        return writer.finish();
    }
}
