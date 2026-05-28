// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer, Writers} from "../Cursors.sol";
import {Forms, Schemas} from "../blocks/Schema.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract AssetStatusHook {
    /// @notice Resolve support status for one asset tuple.
    /// Concrete implementations define the support policy and optional context codes.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @return status Asset support status. Zero means unsupported; nonzero means supported.
    function assetStatus(bytes32 asset, bytes32 meta) internal view virtual returns (uint status);
}

/// @title AssetStatus
/// @notice Rootzero query that checks support status for one or more `(asset, meta)` tuples.
/// The request is a run of `ASSET` blocks.
/// The response returns one `STATUS` form block per query entry, preserving request order.
abstract contract AssetStatus is QueryBase, AssetStatusHook {
    string private constant NAME = "assetStatus";
    uint public immutable assetStatusId = queryId(NAME);

    constructor() {
        emit Query(host, assetStatusId, NAME, "1:1", Schemas.Asset, Forms.Status);
    }

    /// @notice Resolve asset support status for a run of requested `(asset, meta)` tuples.
    /// @param request Block-stream request consisting of `#asset { bytes32 asset, bytes32 meta }` blocks.
    /// @return Block-stream response containing one `#status { uint code }` per asset block.
    function assetStatus(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint groups) = Cursors.first(request, 1);
        Writer memory response = Writers.allocStatuses(groups);

        while (query.i < query.len) {
            (bytes32 asset, bytes32 meta) = query.unpackAsset();
            uint status = assetStatus(asset, meta);
            response.appendStatus(status);
        }

        query.complete();
        return response.finish();
    }
}
