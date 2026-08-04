// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 3: Custom Command
//
// When no built-in module fits your use case, write your own command.
// A command is an abstract contract mixed into a host (not deployed standalone).
//
// Three things every custom command needs:
//   1. A descriptor for the state/input/output streams.
//   2. Metadata defined in the constructor to announce the command to the protocol.
//   3. The onlyCommand modifier on the entrypoint to enforce the trusted caller.

import {CommandBase, Execution, Executions, Lanes, Specs} from "../contracts/Commands.sol";

using Executions for Execution;

abstract contract MyCommand is CommandBase {
    // The descriptor announces accepted input, state, output, and flags.
    uint private immutable descriptor;

    constructor() {
        // Announce this command to the rootzero protocol.
        // Args: label, state, input, output, selector override, funded.
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Balance, 0, false, false);
    }

    function myCommand(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        // onlyCommand checks that msg.sender is the trusted runtime / commander host.
        Execution memory exec = openInput(input, descriptor, 1);
        (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);

        // Apply your app logic here (e.g. debit the account), then append a BALANCE block.
        exec.outputBalance(asset, amount);

        return close(exec, account);
    }
}





