// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 7: Custom Input Shape
//
// Discoverable custom input types define a context-local spec with a small
// literal or selector as its key, then publish it with a #schema annotation.
//
// For:
//
//   { bytes32 asset, uint amount, maybe #status }
//
// the encoded input item is:
//
//   PAYMENT(asset | amount | STATUS(status))

import {Host} from "../contracts/Core.sol";
import {CommandBase, Execution, Executions, Lanes, Sizes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "{ bytes32 asset, uint amount, maybe #status }";

    uint private immutable inputSpec;
    uint private immutable descriptor;

    event PaymentSeen(bytes32 asset, uint amount, uint status);

    constructor() {
        inputSpec = schema(1, 64, 0, uint32(64 + Sizes.Status), INPUT, bytes32(0));
        (, descriptor) = command("myCommand", Specs.Empty, inputSpec, Specs.Empty, 0, false, false);
    }

    function unpackPayment(
        Execution memory exec,
        uint8 lane
    ) private view returns (bytes32 asset, uint amount, uint status) {
        (uint abs, uint end) = exec.enter(lane, inputSpec);

        asset = exec.next32(lane);
        amount = uint(exec.next32(lane));
        abs += 64;

        if (abs < end) {
            status = uint(exec.unpack32(lane, Specs.Status));
            abs += Sizes.Status;
        }

        exec.expectAbs(end);
    }

    function myCommand(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        // The input can batch multiple payment blocks. Each one is decoded
        // with the command-local unpack helper above.
        while (exec.more()) {
            (bytes32 asset, uint amount, uint status) = unpackPayment(exec, Lanes.Input);
            emit PaymentSeen(asset, amount, status);
        }

        return close(exec, account);
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
