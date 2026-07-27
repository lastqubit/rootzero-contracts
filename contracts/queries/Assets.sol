// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {QueryBase} from "./Base.sol";

using Executions for Execution;

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
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = query("assetStatus", Specs.Asset, Specs.Status, 0);
    }

    /// @notice Resolve asset support status for a run of requested assets.
    /// @param request Block-stream request consisting of `asset { bytes32 asset }` blocks.
    /// @return Block-stream response containing one `status { uint code }` form block per asset block.
    function assetStatus(bytes calldata request) external view returns (bytes memory) {
        Execution memory exec = openInput(request, descriptor, 0);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset(Lanes.Input);
            uint status = assetStatus(asset);
            exec.outputStatus(status);
        }

        return end(exec);
    }
}
