// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 8: Transaction Output
//
// Commands can return transaction blocks separately from their regular output.
// The descriptor declares how many transactions each input batch may produce,
// and Execution owns the transaction writer used by the queue helpers.

import {Host} from "../contracts/Core.sol";
import {CommandBase, Execution, Executions, Lanes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;

abstract contract MyCommand is CommandBase {
    uint private immutable descriptor;

    constructor() {
        // Each AMOUNT input batch produces one TRANSACTION block and no regular output.
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Empty, 1, 0);
    }

    function myCommand(
        bytes calldata context
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(context, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            exec.queueCredit(exec.account, asset, amount);
        }

        return closeCommand(exec);
    }
}

// Concrete host so the example can be deployed and called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
