// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { SETUP } from "../../utils/Channels.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
using Blocks for Block;

string constant NAME = "allowAssets";

abstract contract AllowAssets is CommandBase {
    uint internal immutable allowAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, allowAssetsId, SETUP, SETUP);
    }

    /// @dev Override to allow a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function allowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function allowAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(allowAssetsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Asset) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            allowAsset(asset, meta);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
