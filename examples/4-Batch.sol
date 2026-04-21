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

import {CommandBase, CommandContext, State} from "../contracts/Commands.sol";
import {Cur, Cursors, Writer, Writers, Schemas} from "../contracts/Cursors.sol";

using Cursors for Cur;
using Writers for Writer;

string constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, myCommandId, State.Empty, State.Balances, false);
    }

    function myCommand(
        CommandContext calldata c
    ) external onlyTrusted returns (bytes memory) {
        // Create the request cursor from CommandContext.request, then size
        // the writer from the block count returned by primeRun.
        (Cur memory inputs, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocBalances(count);

        // Walk every AMOUNT block in the prime run of the request.
        while (inputs.i < inputs.bound) {
            // Unpack asset, meta, and amount from the next AMOUNT block.
            (bytes32 asset, bytes32 meta, uint amount) = inputs.unpackAmount();

            // Apply your app logic here (e.g. debit the account), then append a BALANCE block.
            writer.appendBalance(asset, meta, amount);
        }

        // Finalize by checking the cursor completed its prime run, then
        // return the encoded BALANCE blocks.
        return inputs.complete(writer);
    }
}






