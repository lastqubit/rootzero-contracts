// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { PortBase } from "./Base.sol";
import { AllowAssetsHook } from "../commands/admin/AllowAssets.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";

using Cursors for Cur;

/// @title PortAllowAssets
/// @notice Port that permits a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `allowAsset`. Restricted to trusted peers.
abstract contract PortAllowAssets is PortBase, AllowAssetsHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portAllowAssets", Keys.Asset, Keys.Empty, 0, false);
    }

    /// @notice Execute the allow-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portAllowAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);

        while (input.i < input.len) {
            bytes32 asset = input.unpackAsset();
            allowAsset(asset);
        }
        return "";
    }
}





