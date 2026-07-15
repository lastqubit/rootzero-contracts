// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 7: Custom Input Shape
//
// Discoverable custom input types define a context-local bytes4 key, such as a
// small literal or selector, and publish it with Schema(host, key, schema, name).
//
// For:
//
//   { bytes32 asset, uint amount, maybe #fee }
//
// the encoded request item is:
//
//   PAYMENT(asset | amount | FEE(fee))

import {Host} from "../contracts/Core.sol";
import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cursors, Cur} from "../contracts/Cursors.sol";

using Cursors for Cur;

abstract contract MyCommand is CommandBase {
    string private constant INPUT = "{ bytes32 asset, uint amount, maybe #fee }";

    bytes32 private immutable descriptor;

    event PaymentSeen(bytes32 asset, uint amount, uint fee);

    constructor() {
        (, descriptor) = command("myCommand", Keys.Empty, localSchema(INPUT), Keys.Empty, 0, false, false);
    }

    function unpackPayment(Cur memory input) private pure returns (bytes32 asset, uint amount, Cur memory fee) {
        uint abs = input.consume(0, Keys.Local, 64, 0);
        asset = bytes32(msg.data[abs:abs + 32]);
        amount = uint(bytes32(msg.data[abs + 32:abs + 64]));
        fee = input.slice(abs + 64 - input.offset, input.i);
    }

    function myCommand(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        // The request can batch multiple payment blocks. Each one is decoded
        // with the command-local unpack helper above.
        while (input.i < input.len) {
            (bytes32 asset, uint amount, Cur memory tail) = unpackPayment(input);
            uint fee = tail.maybeOnly(Keys.Fee) ? tail.unpackFee() : 0;
            emit PaymentSeen(asset, amount, fee);
        }

        input.complete();
        return "";
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
