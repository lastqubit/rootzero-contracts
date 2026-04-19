// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Erc20Cursors } from "../blocks/cursors/Erc20.sol";

using Cursors for Cur;

contract TestErc20CursorHelper {
    function testExpectErc20Amount(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc20Cursors.expectErc20Amount(cur, i);
    }

    function testRequireErc20Amount(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (token, amount) = Erc20Cursors.requireErc20Amount(cur);
        return (token, amount, cur.i);
    }

    function testExpectErc20Balance(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc20Cursors.expectErc20Balance(cur, i);
    }

    function testRequireErc20Balance(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (token, amount) = Erc20Cursors.requireErc20Balance(cur);
        return (token, amount, cur.i);
    }

    function testExpectErc20Custody(
        bytes calldata source,
        uint i,
        uint host
    ) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc20Cursors.expectErc20Custody(cur, i, host);
    }

    function testRequireErc20Custody(
        bytes calldata source,
        uint host
    ) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (token, amount) = Erc20Cursors.requireErc20Custody(cur, host);
        return (token, amount, cur.i);
    }

    function testExpectErc20Minimum(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc20Cursors.expectErc20Minimum(cur, i);
    }

    function testRequireErc20Minimum(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (token, amount) = Erc20Cursors.requireErc20Minimum(cur);
        return (token, amount, cur.i);
    }

    function testExpectErc20Maximum(bytes calldata source, uint i) external view returns (address token, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc20Cursors.expectErc20Maximum(cur, i);
    }

    function testRequireErc20Maximum(bytes calldata source) external view returns (address token, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (token, amount) = Erc20Cursors.requireErc20Maximum(cur);
        return (token, amount, cur.i);
    }

}
