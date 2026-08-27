// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Specs} from "./Base.sol";
using Executions for Execution;

/// @notice Hook implemented by hosts that deny assets.
abstract contract DenyAssetsHook {
    /// @dev Override to deny a single asset.
    /// Called once per ASSET block in the input.
    /// @param asset Asset identifier.
    function denyAsset(bytes32 asset) internal virtual;
}

/// @title DenyAssets
/// @notice Admin command that blocks a list of assets via a virtual hook.
/// Each ASSET block in the input calls `denyAsset`. Only callable by the admin account.
abstract contract DenyAssets is AdminBase, DenyAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("denyAssets", Specs.Empty, Specs.Asset, Specs.Empty, Flags.Admin);
    }

    /// @notice Deny each ASSET block in the admin input.
    /// @param context Admin command context carrying the ASSET input stream.
    /// @return Empty output state.
    /// @return Zero native budget credit.
    function denyAssets(
        bytes calldata context
    ) external returns (bytes memory, uint) {
        Execution memory exec = openAdminCommand(context, descriptor);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset();
            denyAsset(asset);
        }

        return exec.close();
    }
}
