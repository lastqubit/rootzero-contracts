// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
using Cursors for Cur;

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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("allowAssets", Keys.Empty, Keys.Asset, Keys.Empty, 0, false, true);
    }

    /// @notice Allow each ASSET block in the admin request.
    /// @param c Admin command context; `c.input` must contain ASSET blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function allowAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            bytes32 asset = input.unpackAsset();
            allowAsset(asset);
        }
        return ("", "");
    }
}






