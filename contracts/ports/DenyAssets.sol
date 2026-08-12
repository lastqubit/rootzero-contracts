// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {DenyAssetsHook} from "../commands/admin/DenyAssets.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title DenyAssetsPort
/// @notice Port that blocks a list of assets on behalf of a peer host.
/// Each ASSET block in the input calls `denyAsset`. Restricted to trusted peers.
abstract contract DenyAssetsPort is PortBase, DenyAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portDenyAssets", Specs.Asset, Specs.Empty, false);
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
