// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
using Cursors for Cur;

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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("denyAssets", Keys.Empty, Keys.Asset, Keys.Empty, 0, false, true);
    }

    /// @notice Deny each ASSET block in the admin request.
    /// @param c Admin command context; `c.input` must contain ASSET blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function denyAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            bytes32 asset = input.unpackAsset();
            denyAsset(asset);
        }
        return ("", "");
    }
}






