// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Keys } from "../blocks/Keys.sol";
import { Assets } from "../utils/Assets.sol";

using Cursors for Cur;

contract TestErc20CursorHelper {
    function expectErc20Amount(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Amount);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
        meta;
    }

    function expectErc20Balance(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Balance);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
        meta;
    }

    function expectErc20Minimum(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Minimum);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
        meta;
    }

    function expectErc20Maximum(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Maximum);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
        meta;
    }

    function expectErc20HostAssetAmount(Cur memory cur, uint i, uint host) private view returns (address token, uint amount) {
        bytes32 rawHost;
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (rawHost, asset, meta, rawAmount) = Cursors.unpack128(cur, Keys.HostAssetAmount);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
        meta;
    }

    function testExpectErc20Amount(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return expectErc20Amount(cur, i);
    }

    function testRequireErc20Amount(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Amount);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        meta;
        return (token, amount, cur.i);
    }

    function testExpectErc20Balance(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return expectErc20Balance(cur, i);
    }

    function testRequireErc20Balance(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Balance);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        meta;
        return (token, amount, cur.i);
    }

    function testExpectErc20HostAssetAmount(
        bytes calldata source,
        uint i,
        uint host
    ) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return expectErc20HostAssetAmount(cur, i, host);
    }

    function testRequireErc20HostAssetAmount(
        bytes calldata source,
        uint host
    ) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 rawHost;
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        (rawHost, asset, meta, rawAmount) = Cursors.unpack128(cur, Keys.HostAssetAmount);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        meta;
        return (token, amount, cur.i);
    }

    function testExpectErc20Minimum(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return expectErc20Minimum(cur, i);
    }

    function testRequireErc20Minimum(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Minimum);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        meta;
        return (token, amount, cur.i);
    }

    function testExpectErc20Maximum(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return expectErc20Maximum(cur, i);
    }

    function testRequireErc20Maximum(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        bytes32 asset;
        bytes32 meta;
        bytes32 rawAmount;
        (asset, meta, rawAmount) = Cursors.unpack96(cur, Keys.Maximum);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        meta;
        return (token, amount, cur.i);
    }

}
