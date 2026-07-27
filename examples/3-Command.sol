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

import {CommandBase, Specs} from "../contracts/Endpoints.sol";
import {Blocks, Cursors, Cur} from "../contracts/Cursors.sol";

using Cursors for Cur;

abstract contract MyCommand is CommandBase {
    // The descriptor announces accepted input, state, output, and flags.
    uint private immutable descriptor;

    constructor() {
        // Announce this command to the rootzero protocol.
        // Args: label, state, input, output, selector override, funded.
        (, descriptor) = command("myCommand", Specs.Empty, Specs.Amount, Specs.Balance, 0, false, false);
    }

    function myCommand(
        bytes32,
        bytes calldata,
        bytes calldata request
    ) external onlyCommand returns (bytes memory, bytes memory) {
        // onlyCommand checks that msg.sender is the trusted runtime / commander host.
        // Create an input cursor and decode the first AMOUNT block from the
        // input stream.
        Cur memory input = Cursors.openCur(request);
        (bytes32 asset, uint amount) = input.unpackAmount();

        // Apply your app logic here (e.g. debit the account), then return a BALANCE block.
        return (Blocks.balance(asset, amount), "");
    }
}





