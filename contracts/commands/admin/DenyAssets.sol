// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, Execution, Executions, Keys, Lanes, Specs } from "./Base.sol";
using Executions for Execution;

abstract contract DenyAssetsHook {
    /// @dev Override to deny a single asset.
    /// Called once per ASSET block in the request.
    /// @param asset Asset identifier.
    function denyAsset(bytes32 asset) internal virtual;
}

/// @title DenyAssets
/// @notice Admin command that blocks a list of assets via a virtual hook.
/// Each ASSET block in the request calls `denyAsset`. Only callable by the admin account.
abstract contract DenyAssets is AdminBase, DenyAssetsHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("denyAssets", Specs.Empty, Specs.Asset, Specs.Empty, 0, false, true);
    }

    /// @notice Deny each ASSET block in the admin request.
    /// @param input ASSET block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function denyAssets(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            bytes32 asset = exec.unpackAsset(Lanes.Input);
            denyAsset(asset);
        }

        return closeCommand(exec, account);
    }
}






