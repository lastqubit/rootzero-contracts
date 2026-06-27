// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";

using Cursors for Cur;

interface IPortDenyAssets {
    function portDenyAssets(bytes calldata data) external returns (bytes memory);
}

/// @title PortDenyAssets
/// @notice Port that blocks a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PortDenyAssets is PortBase, DenyAssetsHook, IPortDenyAssets {
    uint internal immutable portDenyAssetsId = portId(this.portDenyAssets.selector);

    constructor() {
        emit Port(host, portDenyAssetsId, "1:0", Schemas.Asset, "", false);
        emit Labeled(portDenyAssetsId, bytes32(0), "portDenyAssets");
    }

    /// @notice Execute the deny-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDenyAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory assets, , ) = Cursors.init(data, 1);

        while (assets.i < assets.len) {
            bytes32 asset = assets.unpackAsset();
            denyAsset(asset);
        }

        assets.complete();
        return "";
    }
}





