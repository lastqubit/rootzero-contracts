// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "denyAssets";

abstract contract DenyAssetsHook {
    /// @dev Override to deny a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function denyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);
}

/// @title DenyAssets
/// @notice Admin command that blocks a list of (asset, meta) pairs via a virtual hook.
/// Each ASSET block in the request calls `denyAsset`. Only callable by the admin account.
abstract contract DenyAssets is CommandBase, DenyAssetsHook {
    uint internal immutable denyAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, denyAssetsId, State.Empty, State.Empty, false);
    }

    function denyAssets(
        CommandContext calldata c
    ) external onlyAdmin(c.account) onlyCommand(denyAssetsId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta) = request.unpackAsset();
            denyAsset(asset, meta);
        }

        request.complete();
        return "";
    }
}






