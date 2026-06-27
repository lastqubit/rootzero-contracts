// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { AllowAssetsHook } from "../commands/admin/AllowAssets.sol";
import { Cursors, Cur, Schemas } from "../Cursors.sol";

using Cursors for Cur;

interface IPortAllowAssets {
    function portAllowAssets(bytes calldata data) external returns (bytes memory);
}

/// @title PortAllowAssets
/// @notice Port that permits a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `allowAsset`. Restricted to trusted peers.
abstract contract PortAllowAssets is PortBase, AllowAssetsHook, IPortAllowAssets {
    uint internal immutable portAllowAssetsId = portId(this.portAllowAssets.selector);

    constructor() {
        emit Port(host, portAllowAssetsId, "1:0", Schemas.Asset, "", false);
        emit Labeled(portAllowAssetsId, bytes32(0), "portAllowAssets");
    }

    /// @notice Execute the allow-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portAllowAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = Cursors.init(data, 1);

        while (assets.i < assets.len) {
            bytes32 asset = assets.unpackAsset();
            allowAsset(asset);
        }

        assets.complete();
        return "";
    }
}





