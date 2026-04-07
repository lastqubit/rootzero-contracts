// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Channels } from "../Base.sol";
import { Cursors, Cursor, Keys, Schemas } from "../../Cursors.sol";
using Cursors for Cursor;

string constant NAME = "allowAssets";

abstract contract AllowAssets is CommandBase {
    uint internal immutable allowAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, allowAssetsId, Channels.Setup, Channels.Setup);
    }

    /// @dev Override to allow a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function allowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function allowAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(allowAssetsId, c.target) returns (bytes memory) {
        (Cursor memory assets, ) = Cursors.openRun(c.request, 0, Keys.Asset);

        while (assets.i < assets.end) {
            (bytes32 asset, bytes32 meta) = assets.unpackAsset();
            allowAsset(asset, meta);
        }

        return assets.complete();
    }
}




