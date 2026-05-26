// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetStatus } from "../queries/Assets.sol";

contract TestAssetStatusQuery is AssetStatus {
    bytes32 public immutable allowedAssetId = bytes32(uint(0xA11));
    bytes32 public immutable allowedMeta = bytes32(uint(0xB22));

    function assetStatus(bytes32 asset, bytes32 meta) internal view override returns (uint status) {
        return asset == allowedAssetId && meta == allowedMeta ? 1 : 0;
    }
}
