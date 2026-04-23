// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Keys } from "../blocks/Keys.sol";
import { Assets } from "../utils/Assets.sol";

using Cursors for Cur;
using Assets for bytes32;

contract TestErc721CursorHelper {
    function expectErc721Balance(
        Cur memory cur,
        uint i,
        address collection
    ) private view returns (bytes32 meta) {
        bytes32 asset = Assets.toErc721(collection);
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Balance);
        if (foundAsset.erc721() != asset) revert Cursors.UnexpectedValue();
        if (uint(rawAmount) != 1) revert Cursors.UnexpectedValue();
    }

    function expectErc721HostAssetAmount(
        Cur memory cur,
        uint i,
        uint host,
        address collection
    ) private view returns (bytes32 meta) {
        bytes32 asset = Assets.toErc721(collection);
        bytes32 rawHost;
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (rawHost, foundAsset, meta, rawAmount) = Cursors.unpack128(cur, Keys.HostAssetAmount);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        if (foundAsset.erc721() != asset) revert Cursors.UnexpectedValue();
        if (uint(rawAmount) != 1) revert Cursors.UnexpectedValue();
    }

    function testExpectErc721Balance(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return expectErc721Balance(cur, i, collection);
    }

    function testRequireErc721Balance(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset = Assets.toErc721(collection);
        bytes32 foundAsset;
        bytes32 rawAmount;
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Balance);
        if (foundAsset.erc721() != asset) revert Cursors.UnexpectedValue();
        if (uint(rawAmount) != 1) revert Cursors.UnexpectedValue();
        return (meta, cur.i);
    }

    function testExpectErc721HostAssetAmount(
        bytes calldata source,
        uint i,
        uint host,
        address collection
    ) external view returns (bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return expectErc721HostAssetAmount(cur, i, host, collection);
    }

    function testRequireErc721HostAssetAmount(
        bytes calldata source,
        uint host,
        address collection
    ) external view returns (bytes32 meta, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset = Assets.toErc721(collection);
        bytes32 rawHost;
        bytes32 foundAsset;
        bytes32 rawAmount;
        (rawHost, foundAsset, meta, rawAmount) = Cursors.unpack128(cur, Keys.HostAssetAmount);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        if (foundAsset.erc721() != asset) revert Cursors.UnexpectedValue();
        if (uint(rawAmount) != 1) revert Cursors.UnexpectedValue();
        return (meta, cur.i);
    }
}
