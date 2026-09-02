// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Decoders } from "../Codec.sol";
import { Assets } from "../utils/Assets.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Cursors} from "../utils/Cursors.sol";

using Decoders for Cur;
using Cursors for uint;

contract TestErc20CursorHelper {
    function expectErc20Amount(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        cur.state = cur.state.seek(i);
        (asset, amount) = Decoders.unpackAmount(cur);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Balance(Cur memory cur, uint i) private view returns (address token, uint amount) {
        bytes32 asset;
        cur.state = cur.state.seek(i);
        (asset, amount) = Decoders.unpackBalance(cur);
        token = Assets.erc20Addr(asset);
    }

    function expectErc20Custody(Cur memory cur, uint i, uint host) private view returns (address token, uint amount) {
        uint actualHost;
        bytes32 asset;
        cur.state = cur.state.seek(i);
        (actualHost, asset, amount) = Decoders.unpackCustody(cur);
        if (actualHost != host) revert Blocks.UnexpectedValue();
        token = Assets.erc20Addr(asset);
    }

    function testExpectErc20Amount(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.open(source);
        return expectErc20Amount(cur, Cursors.base(source) + i);
    }

    function testRequireErc20Amount(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.open(source);
        bytes32 asset;
        (asset, amount) = Decoders.unpackAmount(cur);
        token = Assets.erc20Addr(asset);
        i = cur.state.position() - Cursors.base(source);
    }

    function testExpectErc20Balance(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.open(source);
        return expectErc20Balance(cur, Cursors.base(source) + i);
    }

    function testRequireErc20Balance(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.open(source);
        bytes32 asset;
        (asset, amount) = Decoders.unpackBalance(cur);
        token = Assets.erc20Addr(asset);
        i = cur.state.position() - Cursors.base(source);
    }

    function testExpectErc20Custody(
        bytes calldata source,
        uint i,
        uint host
    ) external view returns (address token, uint amount) {
        Cur memory cur = Decoders.open(source);
        return expectErc20Custody(cur, Cursors.base(source) + i, host);
    }

    function testRequireErc20Custody(
        bytes calldata source,
        uint host
    ) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Decoders.open(source);
        uint actualHost;
        bytes32 asset;
        (actualHost, asset, amount) = Decoders.unpackCustody(cur);
        if (actualHost != host) revert Blocks.UnexpectedValue();
        token = Assets.erc20Addr(asset);
        i = cur.state.position() - Cursors.base(source);
    }

}
