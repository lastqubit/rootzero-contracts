// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Erc1155Cursors } from "../blocks/cursors/Erc1155.sol";

using Cursors for Cur;

contract TestErc1155CursorHelper {
    function testExpectErc1155Amount(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc1155Cursors.expectErc1155Amount(cur, i, collection);
    }

    function testRequireErc1155Amount(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Erc1155Cursors.requireErc1155Amount(cur, collection);
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Balance(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc1155Cursors.expectErc1155Balance(cur, i, collection);
    }

    function testRequireErc1155Balance(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Erc1155Cursors.requireErc1155Balance(cur, collection);
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Minimum(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc1155Cursors.expectErc1155Minimum(cur, i, collection);
    }

    function testRequireErc1155Minimum(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Erc1155Cursors.requireErc1155Minimum(cur, collection);
        return (meta, amount, cur.i);
    }

    function testExpectErc1155Maximum(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc1155Cursors.expectErc1155Maximum(cur, i, collection);
    }

    function testRequireErc1155Maximum(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Erc1155Cursors.requireErc1155Maximum(cur, collection);
        return (meta, amount, cur.i);
    }

    function testExpectErc1155CustodyAt(
        bytes calldata source,
        uint i,
        uint host,
        address collection
    ) external view returns (bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return Erc1155Cursors.expectErc1155CustodyAt(cur, i, host, collection);
    }

    function testRequireErc1155CustodyAt(
        bytes calldata source,
        uint host,
        address collection
    ) external view returns (bytes32 meta, uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        (meta, amount) = Erc1155Cursors.requireErc1155CustodyAt(cur, host, collection);
        return (meta, amount, cur.i);
    }
}
