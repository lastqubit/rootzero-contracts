// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cur, Cursors, Keys, Writer, Writers} from "../Cursors.sol";
import {QueryBase} from "../queries/Base.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestQuery is QueryBase {
    bytes4 private immutable Value;
    string private constant INPUT = "{ uint value }";

    bytes32 private immutable descriptor;

    constructor() {
        bytes4 value = schema(1, INPUT);
        Value = value;
        (, descriptor) = query("incrementQuery", value, value, 0);
    }

    function incrementQuery(bytes calldata request) external view returns (bytes memory out) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory output = Writers.alloc32s(outputs);

        while (input.i < input.len) {
            uint foo = uint(input.unpack32(Value));
            output.appendBlock32(Value, bytes32(foo + 1), 32);
        }

        input.complete();
        out = end(output);
    }
}

contract TestKeyedLocalQuery is QueryBase {
    bytes4 private immutable Value;
    string private constant INPUT = "{ uint value }";

    bytes32 private immutable descriptor;

    constructor() {
        bytes4 value = schema(2, INPUT);
        Value = value;
        (, descriptor) = query("keyedLocalQuery", value, value, 0);
    }

    function keyedLocalQuery(bytes calldata request) external view returns (bytes memory out) {
        (Cur memory input, uint outputs) = openInput(request, descriptor);
        Writer memory output = Writers.alloc32s(outputs);

        while (input.i < input.len) {
            uint foo = uint(input.unpack32(Value));
            output.appendBlock32(Value, bytes32(foo + 2), 32);
        }

        input.complete();
        out = end(output);
    }
}
