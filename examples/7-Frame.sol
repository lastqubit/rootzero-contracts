// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 7: Custom Data Shape
//
// A schema that starts with fixed fields is shorthand for one generic DATA
// block. This keeps custom command shapes short while still using `Keys.Data`
// at runtime.
//
// For:
//
//   bytes32 asset, bytes32 meta, uint amount, maybe #fee { uint amount }
//
// the encoded request item is:
//
//   DATA(asset | meta | amount | FEE(fee))
//
// The Command event publishes the schema, while every encoded custom data block
// uses the same `Keys.Data` runtime key.

import {Host} from "../contracts/Core.sol";
import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cursors, Cur, Keys, Schemas} from "../contracts/Cursors.sol";

using Cursors for Cur;

string constant NAME = "myCommand";

string constant INPUT = string.concat("bytes32 asset, bytes32 meta, uint amount, maybe ", Schemas.Fee);

function unpackPayment(Cur memory input) pure returns (bytes32 asset, bytes32 meta, uint amount, Cur memory fee) {
    uint abs = input.consume(0, Keys.Data, 96, 0);
    asset = bytes32(msg.data[abs:abs + 32]);
    meta = bytes32(msg.data[abs + 32:abs + 64]);
    amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    fee = input.slice(abs + 96 - input.offset, input.i);
}

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);
    event PaymentSeen(bytes32 asset, bytes32 meta, uint amount, uint fee);

    constructor() {
        emit Command(host, myCommandId, NAME, "1:0:0", INPUT, Keys.Empty, Keys.Empty, false);
    }

    function myCommand(CommandContext calldata c) external onlyCommand returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        // The request can batch multiple DATA blocks. Each one is decoded
        // with the command-local unpack helper above.
        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount, Cur memory tail) = unpackPayment(request);
            uint fee = tail.maybeOnly(Keys.Fee) ? tail.unpackFee() : 0;
            emit PaymentSeen(asset, meta, amount, fee);
        }

        request.close();
        return "";
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero, 1, "example") {}
}
