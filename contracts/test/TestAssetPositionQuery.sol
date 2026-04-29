// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Keys, Writer, Writers } from "../Cursors.sol";
import { GetPosition } from "../queries/Positions.sol";

using Writers for Writer;

contract TestGetPositionQuery is GetPosition {
    bytes32 public immutable firstAsset = bytes32(uint(0xA11));
    bytes32 public immutable firstMeta = bytes32(uint(0xB11));
    bytes32 public immutable secondAsset = bytes32(uint(0xA22));
    bytes32 public immutable secondMeta = bytes32(uint(0xB22));

    constructor() GetPosition("response(uint position)", 32) {}

    function appendPosition(
        bytes32,
        bytes32 asset,
        bytes32 meta,
        Writer memory response
    ) internal view override {
        uint resolved = 0;
        if (asset == firstAsset && meta == firstMeta) resolved = 11;
        if (asset == secondAsset && meta == secondMeta) resolved = 22;
        response.appendBlock(Keys.Response, abi.encode(resolved));
    }
}
