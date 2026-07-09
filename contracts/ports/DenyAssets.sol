// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Cursors, Cur, Keys} from "../Cursors.sol";

using Cursors for Cur;

/// @title PortDenyAssets
/// @notice Port that blocks a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PortDenyAssets is PortBase, DenyAssetsHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDenyAssets", Keys.Asset, Keys.Empty, 0, false);
    }

    /// @notice Execute the deny-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDenyAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        (Cur memory input, ) = openInput(data, descriptor);

        while (input.i < input.len) {
            bytes32 asset = input.unpackAsset();
            denyAsset(asset);
        }
        return "";
    }
}





