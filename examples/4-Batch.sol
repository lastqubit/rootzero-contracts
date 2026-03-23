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

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {AssetAmount, Blocks, BlockRef, Writers, Writer, AMOUNT, AMOUNT_KEY} from "../contracts/Blocks.sol";

using Blocks for BlockRef;
using Writers for Writer;

string constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, AMOUNT, myCommandId, SETUP, BALANCES);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        uint i = 0;

        // Allocate a writer pre-sized for one BALANCE block per AMOUNT block in the request.
        // `end` is the offset past the last AMOUNT block so the loop knows when to stop.
        (Writer memory writer, uint end) = Writers.allocBalancesFrom(c.request, i, AMOUNT_KEY);

        // Walk every AMOUNT block in the request.
        while (i < end) {
            // Read the block header at offset i to find its key, length, and end position.
            BlockRef memory ref = Blocks.from(c.request, i);

            // Unpack asset, meta, and amount from this block.
            AssetAmount memory value = ref.toAmountValue(c.request);

            // Apply your app logic here (e.g. debit the account), then append a BALANCE block.
            writer.appendBalance(value);

            // Advance the cursor past this block.
            i = ref.end;
        }

        // Finalize and return the encoded BALANCE blocks.
        return writer.done();
    }
}
