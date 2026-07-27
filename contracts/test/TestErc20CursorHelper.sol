// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors, Specs } from "../Cursors.sol";
import { Assets } from "../utils/Assets.sol";
import {Spans} from "../utils/Spans.sol";

using Cursors for Cur;

contract TestErc20CursorHelper {
    function expectErc20Amount(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, rawAmount) = Cursors.unpack64(cur, Specs.Amount);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Balance(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, rawAmount) = Cursors.unpack64(cur, Specs.Balance);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Custody(Cur memory cur, uint i, uint host) private view returns (address token, uint amount) {
        bytes32 rawHost;
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (rawHost, asset, rawAmount) = Cursors.unpack96(cur, Specs.Custody);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function testExpectErc20Amount(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.openCur(source);
        return expectErc20Amount(cur, i);
    }

    function testRequireErc20Amount(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.openCur(source);
        bytes32 asset;
        bytes32 rawAmount;
        (asset, rawAmount) = Cursors.unpack64(cur, Specs.Amount);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testExpectErc20Balance(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.openCur(source);
        return expectErc20Balance(cur, i);
    }

    function testRequireErc20Balance(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.openCur(source);
        bytes32 asset;
        bytes32 rawAmount;
        (asset, rawAmount) = Cursors.unpack64(cur, Specs.Balance);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testExpectErc20Custody(
        bytes calldata source,
        uint i,
        uint host
    ) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.openCur(source);
        return expectErc20Custody(cur, i, host);
    }

    function testRequireErc20Custody(
        bytes calldata source,
        uint host
    ) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.openCur(source);
        bytes32 rawHost;
        bytes32 asset;
        bytes32 rawAmount;
        (rawHost, asset, rawAmount) = Cursors.unpack96(cur, Specs.Custody);
        if (uint(rawHost) != host) revert Cursors.UnexpectedValue();
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Spans.decode(cur.packed);
    }

}
