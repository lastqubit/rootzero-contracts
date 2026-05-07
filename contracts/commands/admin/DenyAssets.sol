// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

abstract contract DenyAssetsHook {
    /// @dev Override to deny a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function denyAsset(bytes32 asset, bytes32 meta) internal virtual;
}

/// @title DenyAssets
/// @notice Admin command that blocks a list of (asset, meta) pairs via a virtual hook.
/// Each ASSET block in the request calls `denyAsset`. Only callable by the admin account.
abstract contract DenyAssets is CommandBase, AdminEvent, DenyAssetsHook {
    string private constant NAME = "denyAssets";

    uint internal immutable denyAssetsId = commandId(NAME);

    constructor() {
        emit Admin(host, denyAssetsId, NAME, "1:0:0", Schemas.Asset, Keys.Empty, Keys.Empty, false);
    }

    function denyAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta) = request.unpackAsset();
            denyAsset(asset, meta);
        }

        request.complete();
        return "";
    }
}






