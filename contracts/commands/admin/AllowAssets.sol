// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "allowAssets";

abstract contract AllowAssetsHook {
    /// @dev Override to allow a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function allowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);
}

/// @title AllowAssets
/// @notice Admin command that permits a list of (asset, meta) pairs via a virtual hook.
/// Each ASSET block in the request calls `allowAsset`. Only callable by the admin account.
abstract contract AllowAssets is CommandBase, AllowAssetsHook {
    uint internal immutable allowAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, allowAssetsId, State.Empty, State.Empty, false);
    }

    function allowAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) onlyCommand(allowAssetsId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta) = request.unpackAsset();
            allowAsset(asset, meta);
        }

        request.complete();
        return "";
    }
}






