// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer, Writers} from "../Cursors.sol";
import {Forms, Schemas} from "../blocks/Schema.sol";
import {QueryBase} from "./Base.sol";

using Cursors for Cur;
using Writers for Writer;

string constant NAME = "isAllowedAsset";

abstract contract IsAllowedAssetHook {
    /// @notice Resolve whether one asset tuple is allowed.
    /// Concrete implementations define the allowlist policy.
    /// @param asset Requested asset identifier.
    /// @param meta Requested asset metadata slot.
    /// @return allowed Whether the asset tuple is allowed.
    function isAllowedAsset(bytes32 asset, bytes32 meta) internal view virtual returns (bool allowed);
}

/// @title IsAllowedAsset
/// @notice Rootzero query that checks whether one or more `(asset, meta)` tuples are allowed.
/// The request is a run of `ASSET` blocks.
/// The response returns one `STATUS` form block per query entry, preserving request order.
abstract contract IsAllowedAsset is QueryBase, IsAllowedAssetHook {
    uint public immutable isAllowedAssetId = queryId(NAME);

    constructor() {
        emit Query(host, isAllowedAssetId, NAME, Schemas.Asset, Forms.Status);
    }

    /// @notice Resolve allowlist status for a run of requested `(asset, meta)` tuples.
    /// @param request Block-stream request consisting of `asset(asset, meta)*`.
    /// @return Block-stream response containing one `status(ok)` per asset block.
    function isAllowedAsset(bytes calldata request) external view returns (bytes memory) {
        (Cur memory query, uint count, ) = cursor(request, 1);
        Writer memory response = Writers.allocStatuses(count);

        while (query.i < query.bound) {
            (bytes32 asset, bytes32 meta) = query.unpackAsset();
            bool allowed = isAllowedAsset(asset, meta);
            response.appendStatus(allowed);
        }

        return query.complete(response);
    }
}
