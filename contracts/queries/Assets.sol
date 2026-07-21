// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Keys, Writer, Writers} from "../Cursors.sol";
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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = query("assetStatus", Keys.Asset, Keys.Status, 0);
    }

    /// @notice Resolve asset support status for a run of requested assets.
    /// @param request Block-stream request consisting of `asset { bytes32 asset }` blocks.
    /// @return Block-stream response containing one `status { uint code }` form block per asset block.
    function assetStatus(bytes calldata request) external view returns (bytes memory) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory response = Writers.allocStatuses(outputs);

        while (input.i < input.len) {
            bytes32 asset = input.unpackAsset();
            uint status = assetStatus(asset);
            response.appendStatus(status);
        }

        return end(response);
    }
}
