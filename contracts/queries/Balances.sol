// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Forms, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

string constant NAME = "getBalances";

abstract contract GetBalancesHook {
    /// @notice Resolve one account's balance for one supported asset.
    /// Concrete implementations define how assets are resolved.
    /// @param account Account identifier carried by the query payload.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @return amount Current balance in the asset's native units.
    function getBalance(bytes32 account, bytes32 asset, bytes32 meta) internal view virtual returns (uint amount);
}

/// @title GetBalances
/// @notice Rootzero query that resolves balances for one or more `(account, asset, meta)` tuples.
/// The request is a run of `ACCOUNT_ASSET` form blocks.
/// The response returns one `ACCOUNT_AMOUNT` form block per requested position, preserving request order.
abstract contract GetBalances is QueryBase, GetBalancesHook {
    uint public immutable getBalancesId = queryId(NAME);

    constructor() {
        emit Query(host, getBalancesId, NAME, Forms.AccountAsset, Forms.AccountAmount);
    }

    /// @notice Resolve balances for a run of requested `(account, asset, meta)` tuples.
    /// @param request Block-stream request consisting of `accountAsset(account, asset, meta)*`.
    /// @return Block-stream response containing one `accountAmount(account, asset, meta, amount)` block per request block.
    function getBalances(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint count, ) = cursor(request, 1);
        Writer memory response = Writers.allocAccountAmounts(count);

        while (query.i < query.bound) {
            (bytes32 account, bytes32 asset, bytes32 meta) = query.unpackAccountAsset();
            uint amount = getBalance(account, asset, meta);
            response.appendAccountAmount(account, asset, meta, amount);
        }

        return query.complete(response);
    }
}
