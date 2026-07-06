// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer, Writers} from "../Cursors.sol";
import {Forms, Schemas} from "../blocks/Schema.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract AssetStatusHook {
    /// @notice Resolve support status for one asset.
    /// Concrete implementations define the support policy and optional context codes.
    /// @param asset Requested asset identifier.
    /// @return status Asset support status. Zero means unsupported; nonzero means supported.
    function assetStatus(bytes32 asset) internal view virtual returns (uint status);
}

/// @title AssetStatus
/// @notice Rootzero query that checks support status for one or more assets.
/// The request is a run of `ASSET` blocks.
/// The response returns one `STATUS` form block per query entry, preserving request order.
abstract contract AssetStatus is QueryBase, AssetStatusHook {
    uint public immutable assetStatusId = queryId(this.assetStatus.selector);

    constructor() {
        emit Query(host, assetStatusId, "1:1", Schemas.Asset, Forms.Status);
        emit Labeled(assetStatusId, bytes32(0), "assetStatus");
    }

    /// @notice Resolve asset support status for a run of requested assets.
    /// @param request Block-stream request consisting of `#asset { bytes32 asset }` blocks.
    /// @return Block-stream response containing one `#status { uint code }` per asset block.
    function assetStatus(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint groups) = Cursors.init(request, 1);
        Writer memory response = Writers.allocStatuses(groups);

        while (query.i < query.len) {
            bytes32 asset = query.unpackAsset();
            uint status = assetStatus(asset);
            response.appendStatus(status);
        }

        query.complete();
        return response.finish();
    }
}
