// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer, Writers} from "../Cursors.sol";
import {Forms} from "../blocks/Schema.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract GetPositionHook {
    /// @notice Append the position response for one requested position.
    /// Concrete implementations must append exactly one response block matching
    /// the query output schema.
    /// @param account Requested account identifier.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @param response Destination writer for the response stream.
    function appendPosition(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        Writer memory response
    ) internal view virtual;
}

/// @title GetPosition
/// @notice Rootzero query that resolves one dynamic position response for each requested position.
/// The request is a run of `ACCOUNT_ASSET` form blocks.
/// The response returns one output-schema block per position entry, preserving request order.
abstract contract GetPosition is QueryBase, GetPositionHook {
    uint public immutable getPositionId = queryId(this.getPosition.selector);

    constructor(string memory output) {
        emit Query(host, getPositionId, "1:1", Forms.AccountAsset, output);
        emit Labeled(getPositionId, bytes32(0), "getPosition");
    }

    /// @notice Resolve positions for a run of requested `(account, asset, meta)` tuples.
    /// @dev Allocates from a per-block capacity hint and grows when position outputs exceed it.
    /// @param request Block-stream request consisting of `accountAsset(account, asset, meta)*`.
    /// @return Block-stream response containing one output-schema block per position block.
    function getPosition(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint groups, ) = Cursors.init(request, 1);
        Writer memory response = Writers.allocAny(groups);

        while (query.i < query.len) {
            (bytes32 account, bytes32 asset, bytes32 meta) = query.unpackAccountAsset();
            appendPosition(account, asset, meta, response);
        }

        query.complete();
        return response.finish();
    }
}
