// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {AllowAssetsHook} from "../commands/admin/AllowAssets.sol";
import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PortAllowAssets
/// @notice Port that permits a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `allowAsset`. Restricted to trusted peers.
abstract contract PortAllowAssets is PortBase, AllowAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portAllowAssets", Specs.Asset, Specs.Empty, 0, false);
    }

    /// @notice Execute the allow-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portAllowAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset(Lanes.Input);
            allowAsset(asset);
        }
        return "";
    }
}
