// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 7: Custom Input Shape
//
// Discoverable custom input types define a context-local spec with a small
// literal or selector as its key, then publish it with Schema(host, spec, schema, name).
//
// For:
//
//   { bytes32 asset, uint amount, maybe #fee }
//
// the encoded request item is:
//
//   PAYMENT(asset | amount | FEE(fee))

import {Host} from "../contracts/Core.sol";
import {CommandBase, Execution, Executions, Keys, Lanes, Specs} from "../contracts/Endpoints.sol";
import {Decoders, Cur, Sizes} from "../contracts/Cursors.sol";
import {Cursors} from "../contracts/utils/Cursors.sol";

using Decoders for Cur;
using Executions for Execution;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "{ bytes32 asset, uint amount, maybe #fee }";

    uint private immutable inputSpec;
    uint private immutable descriptor;

    event PaymentSeen(bytes32 asset, uint amount, uint fee);

    constructor() {
        inputSpec = schema(1, 64, 0, uint32(64 + Sizes.Fee), INPUT, bytes32(0));
        (, descriptor) = command("myCommand", Specs.Empty, inputSpec, Specs.Empty, 0, false, false);
    }

    function unpackPayment(
        Execution memory exec,
        uint8 tag_
    ) private view returns (bytes32 asset, uint amount, Cur memory fee) {
        Cur memory input = Cur(Cursors.select(exec.cursors, tag_));
        uint end = input.enter(inputSpec);
        asset = input.read32();
        amount = input.readUint();
        (uint i, , ) = Cursors.decode(input.packed);
        fee = input.slice(i, end);
        input.seek(end);
        exec.cursors = input.packed;
    }

    function myCommand(
        bytes32,
        bytes calldata,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        // The request can batch multiple payment blocks. Each one is decoded
        // with the command-local unpack helper above.
        while (exec.more()) {
            (bytes32 asset, uint amount, Cur memory tail) = unpackPayment(exec, Lanes.Input);
            uint fee = tail.maybeOnly(Keys.Fee) ? tail.unpackFee() : 0;
            emit PaymentSeen(asset, amount, fee);
        }

        exec.complete(Lanes.Input);
        return ("", "");
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
