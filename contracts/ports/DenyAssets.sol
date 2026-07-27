// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PortDenyAssets
/// @notice Port that blocks a list of assets on behalf of a peer host.
/// Each ASSET block in the request calls `denyAsset`. Restricted to trusted peers.
abstract contract PortDenyAssets is PortBase, DenyAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDenyAssets", Specs.Asset, Specs.Empty, 0, false);
    }

    /// @notice Execute the deny-assets peer call.
    /// @param data ASSET block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portDenyAssets(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset(Lanes.Input);
            denyAsset(asset);
        }
        return "";
    }
}
