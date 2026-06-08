// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

abstract contract AllowAssetsHook {
    /// @dev Override to allow a single asset/meta pair.
    /// Called once per ASSET block in the request.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    function allowAsset(bytes32 asset, bytes32 meta) internal virtual;
}

/// @title AllowAssets
/// @notice Admin command that permits a list of (asset, meta) pairs via a virtual hook.
/// Each ASSET block in the request calls `allowAsset`. Only callable by the admin account.
abstract contract AllowAssets is CommandBase, AdminEvent, AllowAssetsHook {
    uint internal immutable allowAssetsId = commandId(this.allowAssets.selector);

    constructor() {
        emit Admin(host, allowAssetsId, "1:0:0", Schemas.Asset, Keys.Empty, Keys.Empty, false, false);
        emit Labeled(allowAssetsId, bytes32(0), "allowAssets");
    }

    /// @notice Allow each ASSET block in the admin request.
    /// @param c Admin command context; `c.request` must contain ASSET blocks.
    /// @return Empty output state.
    function allowAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 0, 1);

        while (request.i < request.len) {
            (bytes32 asset, bytes32 meta) = request.unpackAsset();
            allowAsset(asset, meta);
        }

        request.complete();
        return "";
    }
}






