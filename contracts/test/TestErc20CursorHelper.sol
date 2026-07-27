// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Decoders, Specs } from "../Cursors.sol";
import { Assets } from "../utils/Assets.sol";
import {Cursors} from "../utils/Cursors.sol";

using Decoders for Cur;

contract TestErc20CursorHelper {
    function expectErc20Amount(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, rawAmount) = Decoders.unpack64(cur, Specs.Amount);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Balance(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (asset, rawAmount) = Decoders.unpack64(cur, Specs.Balance);
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Custody(Cur memory cur, uint i, uint host) private view returns (address token, uint amount) {
        bytes32 rawHost;
        bytes32 asset;
        bytes32 rawAmount;
        cur = cur.seek(i);
        (rawHost, asset, rawAmount) = Decoders.unpack96(cur, Specs.Custody);
        if (uint(rawHost) != host) revert Decoders.UnexpectedValue();
        amount = uint(rawAmount);
        token = Assets.erc20Addr(asset);
    }

    function testExpectErc20Amount(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.openCur(source);
        return expectErc20Amount(cur, i);
    }

    function testRequireErc20Amount(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.openCur(source);
        bytes32 asset;
        bytes32 rawAmount;
        (asset, rawAmount) = Decoders.unpack64(cur, Specs.Amount);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Cursors.decode(cur.packed);
    }

    function testExpectErc20Balance(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.openCur(source);
        return expectErc20Balance(cur, i);
    }

    function testRequireErc20Balance(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.openCur(source);
        bytes32 asset;
        bytes32 rawAmount;
        (asset, rawAmount) = Decoders.unpack64(cur, Specs.Balance);
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Cursors.decode(cur.packed);
    }

    function testExpectErc20Custody(
        bytes calldata source,
        uint i,
        uint host
    ) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.openCur(source);
        return expectErc20Custody(cur, i, host);
    }

    function testRequireErc20Custody(
        bytes calldata source,
        uint host
    ) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.openCur(source);
        bytes32 rawHost;
        bytes32 asset;
        bytes32 rawAmount;
        (rawHost, asset, rawAmount) = Decoders.unpack96(cur, Specs.Custody);
        if (uint(rawHost) != host) revert Decoders.UnexpectedValue();
        token = Assets.erc20Addr(asset);
        amount = uint(rawAmount);
        (i, , ) = Cursors.decode(cur.packed);
    }

}
