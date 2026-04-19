// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "../Cursors.sol";
import { Erc721Cursors } from "../blocks/cursors/Erc721.sol";

using Cursors for Cur;

contract TestErc721CursorHelper {
    function testExpectErc721Balance(
        bytes calldata source,
        uint i,
        address collection
    ) external view returns (bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return Erc721Cursors.expectErc721Balance(cur, i, collection);
    }

    function testRequireErc721Balance(
        bytes calldata source,
        address collection
    ) external view returns (bytes32 meta, uint i) {
        Cur memory cur = Cursors.open(source);
        meta = Erc721Cursors.requireErc721Balance(cur, collection);
        return (meta, cur.i);
    }

    function testExpectErc721Custody(
        bytes calldata source,
        uint i,
        uint host,
        address collection
    ) external view returns (bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return Erc721Cursors.expectErc721Custody(cur, i, host, collection);
    }

    function testRequireErc721Custody(
        bytes calldata source,
        uint host,
        address collection
    ) external view returns (bytes32 meta, uint i) {
        Cur memory cur = Cursors.open(source);
        meta = Erc721Cursors.requireErc721Custody(cur, host, collection);
        return (meta, cur.i);
    }
}
