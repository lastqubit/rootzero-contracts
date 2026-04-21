// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Schemas, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;

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
/// The request is a run of `POSITION` blocks.
/// The response returns one `ENTRY` block per position entry, preserving request order.
abstract contract GetBalances is QueryBase, GetBalancesHook {
    uint public immutable getBalancesId = queryId(NAME);

    constructor() {
        emit Query(host, NAME, Schemas.Position, Schemas.Entry, getBalancesId);
    }

    /// @notice Resolve balances for a run of requested `(account, asset, meta)` tuples.
    /// @param request Block-stream request consisting of `position(account, asset, meta)*`.
    /// @return Block-stream response containing one `entry(account, asset, meta, amount)` per position block.
    function getBalances(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint count, ) = cursor(request, 1);
        Writer memory response = Writers.allocEntries(count);

        while (query.i < query.bound) {
            (bytes32 account, bytes32 asset, bytes32 meta) = query.unpackPosition();
            uint balance = getBalance(account, asset, meta);
            Writers.appendEntry(response, account, asset, meta, balance);
        }

        return query.complete(response);
    }
}
