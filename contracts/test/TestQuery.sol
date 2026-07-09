// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Keys, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "../queries/Base.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestQuery is QueryBase {
    bytes4 private immutable Value = Keys.local(1);
    bytes32 private constant ValueName = bytes32("value");
    string private constant ValueSchema = "{ uint value }";

    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = query("incrementQuery", schema(Value, ValueSchema, ValueName), Value, 0);
    }

    function incrementQuery(bytes calldata request) external view returns (bytes memory out) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory output = Writers.alloc32s(outputs);

        while (input.i < input.len) {
            uint foo = uint(input.unpack32(Value));
            output.appendBlock32(Value, bytes32(foo + 1), 32);
        }

        input.complete();
        out = output.finish();
    }
}
