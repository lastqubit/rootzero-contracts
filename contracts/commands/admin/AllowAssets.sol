// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, Execution, Executions, Keys, Lanes, Specs } from "./Base.sol";
using Executions for Execution;

abstract contract AllowAssetsHook {
    /// @dev Override to allow a single asset.
    /// Called once per ASSET block in the request.
    /// @param asset Asset identifier.
    function allowAsset(bytes32 asset) internal virtual;
}

/// @title AllowAssets
/// @notice Admin command that permits a list of assets via a virtual hook.
/// Each ASSET block in the request calls `allowAsset`. Only callable by the admin account.
abstract contract AllowAssets is AdminBase, AllowAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("allowAssets", Specs.Empty, Specs.Asset, Specs.Empty, 0, false, true);
    }

    /// @notice Allow each ASSET block in the admin request.
    /// @param input ASSET block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function allowAssets(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset(Lanes.Input);
            allowAsset(asset);
        }

        return closeCommand(exec, account);
    }
}






