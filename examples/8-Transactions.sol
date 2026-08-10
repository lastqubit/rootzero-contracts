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
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Empty, 1, false, false);
    }

    function myCommand(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            exec.queueCredit(account, asset, amount);
        }

        return close(exec, account);
    }
}

// Concrete host so the example can be deployed and called in tests.
contract ExampleHost is Host, MyCommand {
    constructor(address rootzero) Host(rootzero) {}
}
