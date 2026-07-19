// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 4: Batch Processing
//
// Requests can contain multiple blocks of the same type.
// This example shows how to iterate over all AMOUNT blocks in a request
// and produce a matching BALANCE block for each one.
//
// Use Writers when you need to build the response incrementally rather than
// returning a single pre-encoded block.

import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cur, Cursors, Writer, Writers} from "../contracts/Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract MyCommand is CommandBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("myCommand", Keys.Empty, Keys.Amount, Keys.Balance, 0, false, false);
    }

    function myCommand(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory state, bytes memory transactions) {
        // Open the descriptor input stream, then size the writer from the
        // expected output block count returned by the endpoint helper.
        (Cur memory input, uint outputs) = openInput(c.input, descriptor);
        Writer memory output = Writers.allocBalances(outputs);

        // Walk every AMOUNT block in the current request run.
        while (input.i < input.len) {
            // Unpack asset and amount from the next AMOUNT block.
            (bytes32 asset, uint amount) = input.unpackAmount();

            // Apply your app logic here (e.g. debit the account), then append a BALANCE block.
            output.appendBalance(asset, amount);
        }

        // Finalize by checking the cursor completed its run, then
        // return the encoded BALANCE blocks.
        input.complete();
        return (output.finish(), "");
    }
}






