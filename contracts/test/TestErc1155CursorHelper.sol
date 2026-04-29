// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Keys } from "../blocks/Keys.sol";
import { Assets } from "../utils/Assets.sol";

using Cursors for Cur;
using Assets for bytes32;

contract TestErc1155CursorHelper {
    function testExpectErc1155Amount(
        bytes calldata source,
        uint i,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Amount, 32);
        amount = uint(rawAmount);
        if (foundAsset != asset.erc1155()) revert Cursors.UnexpectedValue();
    }

    function testRequireErc1155Amount(
        bytes calldata source,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Cursors.requireAssetAmount(cur, Keys.Amount, asset.erc1155());
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Balance(
        bytes calldata source,
        uint i,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Balance, 32);
        amount = uint(rawAmount);
        if (foundAsset != asset.erc1155()) revert Cursors.UnexpectedValue();
    }

    function testRequireErc1155Balance(
        bytes calldata source,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Cursors.requireAssetAmount(cur, Keys.Balance, asset.erc1155());
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Minimum(
        bytes calldata source,
        uint i,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Minimum, 32);
        amount = uint(rawAmount);
        if (foundAsset != asset.erc1155()) revert Cursors.UnexpectedValue();
    }

    function testRequireErc1155Minimum(
        bytes calldata source,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Cursors.requireAssetAmount(cur, Keys.Minimum, asset.erc1155());
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Maximum(
        bytes calldata source,
        uint i,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (foundAsset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Maximum, 32);
        amount = uint(rawAmount);
        if (foundAsset != asset.erc1155()) revert Cursors.UnexpectedValue();
    }

    function testRequireErc1155Maximum(
        bytes calldata source,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Cursors.requireAssetAmount(cur, Keys.Maximum, asset.erc1155());
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Custody(
        bytes calldata source,
        uint i,
        uint host,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        bytes32 rawHost;
        bytes32 foundAsset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (rawHost, foundAsset, meta, rawAmount) = Cursors.unpack128(cur, Keys.Custody, 32);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        amount = uint(rawAmount);
        if (foundAsset != asset.erc1155()) revert Cursors.UnexpectedValue();
    }

    function testRequireErc1155Custody(
        bytes calldata source,
        uint host,
        bytes32 asset
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Cursors.requireHostAmount(cur, Keys.Custody, host, asset.erc1155());
        return (meta, amount, cur.i);
    }
}
