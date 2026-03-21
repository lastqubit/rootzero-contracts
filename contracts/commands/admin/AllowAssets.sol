// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, SETUP} from "../Base.sol";
import {ASSET, ASSET_KEY, BlockRef} from "../../blocks/Schema.sol";
import {Blocks} from "../../blocks/Readers.sol";
using Blocks for BlockRef;

string constant NAME = "allowAssets";

abstract contract AllowAssets is CommandBase {
    uint internal immutable allowAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ASSET, allowAssetsId, SETUP, SETUP);
    }

    function allowAsset(bytes32 asset, bytes32 meta) internal virtual;

    function allowAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(allowAssetsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            BlockRef memory ref = Blocks.from(c.request, i);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset(c.request);
            allowAsset(asset, meta);
            i = ref.end;
        }
        return done(0, i);
    }
}
