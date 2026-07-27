// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Sizes} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {QueryBase} from "../queries/Base.sol";

using Executions for Execution;

contract TestQuery is QueryBase {
    uint private immutable ValueSpec;
    string private constant INPUT = "{ uint value }";

    uint private immutable descriptor;

    constructor() {
        uint32 size = uint32(Sizes.B32 - Sizes.Header);
        uint valueSpec = schema(1, size, size, size, INPUT, bytes32(0));
        ValueSpec = valueSpec;
        (, descriptor) = query("incrementQuery", valueSpec, valueSpec, 0);
    }

    function incrementQuery(bytes calldata request) external view returns (bytes memory out) {
        Execution memory exec = openInput(request, descriptor, 0);
        uint valueSpec = ValueSpec;

        while (exec.more()) {
            uint foo = uint(exec.unpack32(Lanes.Input, valueSpec));
            exec.outputBlock32(valueSpec, bytes32(foo + 1));
        }

        exec.complete(Lanes.Input);
        out = closeExecution(exec);
    }
}

contract TestKeyedLocalQuery is QueryBase {
    uint private immutable ValueSpec;
    string private constant INPUT = "{ uint value }";

    uint private immutable descriptor;

    constructor() {
        uint32 size = uint32(Sizes.B32 - Sizes.Header);
        uint valueSpec = schema(2, size, size, size, INPUT, bytes32(0));
        ValueSpec = valueSpec;
        (, descriptor) = query("keyedLocalQuery", valueSpec, valueSpec, 0);
    }

    function keyedLocalQuery(bytes calldata request) external view returns (bytes memory out) {
        Execution memory exec = openInput(request, descriptor, 0);
        uint valueSpec = ValueSpec;

        while (exec.more()) {
            uint foo = uint(exec.unpack32(Lanes.Input, valueSpec));
            exec.outputBlock32(valueSpec, bytes32(foo + 2));
        }

        exec.complete(Lanes.Input);
        out = closeExecution(exec);
    }
}
