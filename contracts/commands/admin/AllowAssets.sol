// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {ASSET, ASSET_KEY} from "../../blocks/Schema.sol";
import {Data, DataRef} from "../../Blocks.sol";
using Data for DataRef;

string constant NAME = "allowAssets";

abstract contract AllowAssets is CommandBase {
    uint internal immutable allowAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ASSET, allowAssetsId, SETUP, SETUP);
    }

    /// @dev Override to allow a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function allowAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function allowAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(allowAssetsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            DataRef memory ref = Data.from(c.request, i);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            allowAsset(asset, meta);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
