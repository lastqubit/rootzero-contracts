// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 3: Custom Command
//
// When no built-in module fits your use case, write your own command.
// A command is an abstract contract mixed into a host (not deployed standalone).
//
// Three things every custom command needs:
//   1. A deterministic command ID derived from the command name + address.
//   2. A Command event emitted in the constructor to announce the command to the protocol.
//   3. The onlyCommand modifier on the entrypoint to enforce the trusted caller.

import {CommandBase, CommandContext, Keys} from "../contracts/Endpoints.sol";
import {Cursors, Cur, Schemas} from "../contracts/Cursors.sol";

using Cursors for Cur;

abstract contract MyCommand is CommandBase {
    // commandId() hashes the selector with the contract address to produce a unique ID.
    // Immutable so it is computed once at deploy time.
    uint internal immutable myCommandId = commandId(this.myCommand.selector);

    constructor() {
        // Announce this command to the rootzero protocol.
        // Args: host id, command id, request shape, request schema, input channel, output channel.
        // SETUP = no structured input channel; BALANCES = this command returns BALANCE blocks.
        emit Command(host, myCommandId, "1:0:1", Schemas.Amount, Keys.Empty, Keys.Balance, false);
        emit Labeled(myCommandId, bytes32(0), "myCommand");
    }

    function myCommand(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory) {
        // onlyCommand checks that msg.sender is the trusted runtime / commander host.
        // The command function selector already identifies this entrypoint, so no
        // additional target field is needed in CommandContext.

        // CommandContext now carries just account, state, and request.
        // Create a request cursor using the shared command helper and decode
        // the first AMOUNT block from the request stream.
        Cur memory input = Cursors.open(c.request);
        (bytes32 asset, bytes32 meta, uint amount) = input.unpackAmount();

        // Apply your app logic here (e.g. debit the account), then return a BALANCE block.
        return Cursors.toBalanceBlock(asset, meta, amount);
    }
}





