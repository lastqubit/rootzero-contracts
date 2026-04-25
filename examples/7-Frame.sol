// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 7: Frame Blocks
//
// `payment = amount(...) + fee(...)` means: one FRAME block whose payload is
// the merged payload fields of AMOUNT followed by FEE, without child block
// headers.
//
// For:
//
//   payment = amount(bytes32 asset, bytes32 meta, uint amount) + fee(uint amount)
//
// the encoded request item is:
//
//   FRAME(asset | meta | amount | fee)
//
// The Command event publishes the schema, while every encoded frame uses the
// same `Keys.Frame` runtime key.

import {Host} from "../contracts/Core.sol";
import {CommandBase, CommandContext, State} from "../contracts/Commands.sol";
import {Cursors, Cur, Keys, Schemas} from "../contracts/Cursors.sol";

using Cursors for Cur;

string constant NAME = "myCommand";

// `payment = ...` names the frame in schema metadata. The runtime key is
// still `Keys.Frame`; the schema name tells tools and readers what it means.
string constant INPUT = string.concat("payment = ", Schemas.Amount, "+", Schemas.Fee);

function unpackPayment(Cur memory input) pure returns (bytes32 asset, bytes32 meta, uint amount, uint fee) {
    (bytes32 a, bytes32 b, bytes32 c, bytes32 d) = input.unpack128(Keys.Frame, 32);
    return (a, b, uint(c), uint(d));
}

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);
    event PaymentSeen(bytes32 asset, bytes32 meta, uint amount, uint fee);

    constructor() {
        emit Command(host, NAME, INPUT, myCommandId, State.Empty, State.Empty, false);
    }

    function myCommand(CommandContext calldata c) external onlyTrusted returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        // The request can batch multiple FRAME blocks. Each one is decoded
        // with the command-local unpack helper above.
        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount, uint fee) = unpackPayment(request);
            emit PaymentSeen(asset, meta, amount, fee);
        }

        request.complete();
        return "";
    }
}

// Concrete host so the example can be deployed and the command can be called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero, 1, "example") {}
}
