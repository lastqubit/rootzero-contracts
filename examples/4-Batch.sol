// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 4: Batch Processing
//
// Inputs can contain multiple blocks of the same type.
// This example shows how to iterate over all AMOUNT blocks in a input
// and produce a matching BALANCE block for each one.
//
// Execution owns the response buffer and grows it through output helpers.

import {CommandBase, Execution, Executions, Lanes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;

abstract contract MyCommand is CommandBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Balance, 0, false, false);
    }

    function myCommand(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        // Open and validate both descriptor lanes and initialize the output buffer.
        Execution memory exec = openCommand(state, input, descriptor, 0);

        // Walk every AMOUNT block in the current input run.
        while (exec.more()) {
            // Unpack asset and amount from the next AMOUNT block.
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);

            // Apply your app logic here (e.g. debit the account), then append a BALANCE block.
            exec.outputBalance(asset, amount);
        }

        return close(exec, account);
    }
}






