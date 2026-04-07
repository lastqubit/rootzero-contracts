// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "denyAssets";

abstract contract DenyAssets is CommandBase {
    uint internal immutable denyAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, denyAssetsId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to deny a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function denyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function denyAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(denyAssetsId, c.target) returns (bytes memory) {
        Cursor memory assets = Cursors.openRun(c.request, 0, Keys.Asset, 1);

        while (assets.i < assets.end) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            denyAsset(asset, meta);
        }

        return assets.complete();
    }
}




