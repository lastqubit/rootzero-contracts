// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext } from "../Base.sol";
import { SETUP } from "../../utils/Channels.sol";
import { Keys } from "../../blocks/Keys.sol";
import { Schemas } from "../../blocks/Schema.sol";
import { Blocks, Block, Keys } from "../../Blocks.sol";
using Blocks for Block;

string constant NAME = "denyAssets";

abstract contract DenyAssets is CommandBase {
    uint internal immutable denyAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Asset, denyAssetsId, SETUP, SETUP);
    }

    /// @dev Override to deny a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function denyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function denyAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(denyAssetsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            Block memory ref = Blocks.from(c.request, i);
            if (ref.key != Keys.Asset) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            denyAsset(asset, meta);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
