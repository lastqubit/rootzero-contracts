// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks, Cur, Decoders, Specs, Writer} from "../Codec.sol";
import {Writers} from "../codec/Writers.sol";
import {Cursors} from "../utils/Cursors.sol";

using Decoders for Cur;
using Writers for Writer;

contract TestStringCursorHelper {
    function testWriteStringBlock(string memory data) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.String, 1);
        w.appendString(data);
        return w.finish();
    }

    function testToStringBlock(string memory data) external pure returns (bytes memory) {
        return Blocks.text(data);
    }

    function testUnpackString(bytes calldata source) external pure returns (string memory data, uint i) {
        Cur memory cur = Decoders.wrap(source);
        data = cur.unpackString();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackLabel(
        bytes calldata source
    ) external pure returns (uint id, bytes32 namespace, string memory name, uint i) {
        Cur memory cur = Decoders.wrap(source);
        (id, namespace, name) = cur.unpackLabel();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackSchema(
        bytes calldata source
    ) external pure returns (uint spec, string memory body, bytes32 name, uint i) {
        Cur memory cur = Decoders.wrap(source);
        (spec, body, name) = cur.unpackSchema();
        (i, , ) = Cursors.decode(cur.state);
    }
}
