// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {AssetAmount, HostAmount, CUSTODY_KEY, ROUTE_KEY} from "../Schema.sol";
import {Blocks, BlockRef, Data, DataRef, Writers, Writer} from "../Blocks.sol";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;

abstract contract CustodyToBalance {
    function custodyToBalance(
        uint host,
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual returns (AssetAmount memory);

    function custodiesToBalances(bytes calldata blocks, uint i, bytes32 account) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(blocks, i, CUSTODY_KEY);

        while (i < end) {
            BlockRef memory ref = Blocks.custodyFrom(blocks, i);
            HostAmount memory c = ref.toCustodyValue(blocks);
            AssetAmount memory out = custodyToBalance(c.host, account, c.asset, c.meta, c.amount);
            if (out.amount > 0) writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}

/* abstract contract CustodyToBalanceWithRequestRoute is CommandBase {
    function mapCustodyWithRequestRoute(
        bytes32 account,
        HostAmount memory custody,
        DataRef memory rawRoute
    ) internal virtual returns (HostAmount memory out);

    function mapCustodiesWithRequestRoutes(
        bytes calldata state,
        bytes calldata request,
        uint i,
        uint q,
        bytes32 account
    ) internal returns (bytes memory) {
        (Writer memory writer, uint end) = Writers.allocCustodiesFrom(state, i, CUSTODY_KEY);

        while (i < end) {
            DataRef memory route;
            (route, q) = Data.routeFrom(request, q);
            BlockRef memory ref = Blocks.custodyFrom(state, i);
            HostAmount memory custody = ref.toCustodyValue(state);
            HostAmount memory out = mapCustodyWithRequestRoute(account, custody, route);
            if (out.amount > 0) writer.appendCustody(out);
            i = ref.end;
        }

        return writer.finish();
    }
} */

// Route-aware amount transforms read one child route per amount block, e.g. `AMOUNT > ROUTE`.
/* abstract contract CustodyToBalanceWithRequestRoute is CommandBase {
    function amountWithChildRouteToBalance(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount,
        DataRef memory rawRoute
    ) internal virtual returns (AssetAmount memory);

    function amountsWithChildRoutesToBalances(
        bytes calldata blocks,
        uint i,
        bytes32 account
    ) internal returns (bytes memory) {
        (Writer memory writer, uint next) = Writers.allocBalancesFrom(blocks, i, CUSTODY_KEY);

        while (i < next) {
            BlockRef memory ref = Blocks.amountFrom(blocks, i);
            DataRef memory route = Data.findFrom(blocks, ref.bound, ref.end, ROUTE_KEY);
            (bytes32 asset, bytes32 meta, uint amount) = ref.unpackAmount(blocks);
            AssetAmount memory out = amountWithChildRouteToBalance(account, asset, meta, amount, route);
            writer.appendBalance(out);
            i = ref.end;
        }

        return writer.finish();
    }
}
 */
