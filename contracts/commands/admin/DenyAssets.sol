// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "../Base.sol";
import {SETUP} from "../../utils/Channels.sol";
import {ASSET, ASSET_KEY} from "../../blocks/Schema.sol";
import {Data, DataRef} from "../../Blocks.sol";
using Data for DataRef;

string constant NAME = "denyAssets";

abstract contract DenyAssets is CommandBase {
    uint internal immutable denyAssetsId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, ASSET, denyAssetsId, SETUP, SETUP);
    }

    /// @dev Override to deny a single asset/meta pair.
    /// Called once per ASSET block in the request.
    function denyAsset(bytes32 asset, bytes32 meta) internal virtual returns (bool);

    function denyAssets(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(denyAssetsId, c.target) returns (bytes memory) {
        uint i = 0;
        while (i < c.request.length) {
            DataRef memory ref = Data.from(c.request, i);
            if (ref.key != ASSET_KEY) break;
            (bytes32 asset, bytes32 meta) = ref.unpackAsset();
            denyAsset(asset, meta);
            i = ref.cursor;
        }
        return done(0, i);
    }
}
