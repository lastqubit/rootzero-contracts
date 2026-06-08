// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Writer} from "../Cursors.sol";
import {Writers} from "../blocks/Writers.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestStringCursorHelper {
    function testWriteStringBlock(string memory data) external pure returns (bytes memory) {
        Writer memory w = Writers.allocStrings(1);
        w.appendString(data);
        return w.finish();
    }

    function testToStringBlock(string memory data) external pure returns (bytes memory) {
        return Cursors.toStringBlock(data);
    }

    function testUnpackString(bytes calldata source) external pure returns (string memory data, uint i) {
        Cur memory cur = Cursors.open(source);
        data = cur.unpackString();
        i = cur.i;
    }

    function testUnpackLabel(
        bytes calldata source
    ) external pure returns (uint id, bytes32 namespace, string memory name, uint i) {
        Cur memory cur = Cursors.open(source);
        (id, namespace, name) = cur.unpackLabel();
        i = cur.i;
    }
}
