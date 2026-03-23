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
//   3. The onlyCommand modifier on the entrypoint to enforce the trusted caller and target.

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {Blocks, AMOUNT} from "../contracts/Blocks.sol";

// NAME is the human-readable command name. It is used to derive the command ID
// and is published in the Command event so off-chain tooling can discover it.
string constant NAME = "myCommand";

abstract contract MyCommand is CommandBase {
    // commandId() hashes the name with the contract address to produce a unique ID.
    // Immutable so it is computed once at deploy time.
    uint internal immutable myCommandId = commandId(NAME);

    constructor() {
        // Announce this command to the Rush protocol.
        // Args: host id, command name, request schema, command id, input channel, output channel.
        // SETUP = no structured input channel; BALANCES = this command returns BALANCE blocks.
        emit Command(host, NAME, AMOUNT, myCommandId, SETUP, BALANCES);
    }

    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        // onlyCommand checks that msg.sender is the trusted Rush runtime and that
        // c.target matches this command's ID (or is 0, meaning "any command").

        // Decode the first AMOUNT block from the request at offset 0.
        (bytes32 asset, bytes32 meta, uint amount) = Blocks.unpackAmountAt(c.request, 0);

        // Apply your app logic here (e.g. debit the account), then return a BALANCE block.
        return Blocks.toBalanceBlock(asset, meta, amount);
    }
}
