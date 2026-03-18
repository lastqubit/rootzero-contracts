// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, BALANCES, SETUP} from "../contracts/Commands.sol";
import {AMOUNT} from "../contracts/Schema.sol";
import {toCommandId} from "../contracts/Utils.sol";

// Pick a stable command name and keep it in sync with the external function below.
// Rush uses this name when the host announces the command during deployment.
bytes32 constant NAME = "myCommand";

// The schema tells clients what request blocks this command expects.
// Top-level blocks are separated with `;` and nested blocks use `>`.
string constant SCHEMA = AMOUNT;

// `STATEIN` is metadata for clients: it describes the state shape this command expects to receive.
// It helps offchain tooling compose flows, but it does not enforce anything onchain by itself.
uint8 constant STATEIN = SETUP;

// `STATEOUT` is the matching hint for the state this command returns to the next step in a flow.
uint8 constant STATEOUT = BALANCES;

abstract contract MyCommand is CommandBase {
    // Command ids are derived from the command name and host address, making them deterministic and unique
    // to this host even across chains.
    uint internal immutable myCommandId = toCommandId(NAME, address(this));

    constructor() {
        // Announce the command once at deployment so clients can discover its name, schema, and state hints.
        emit Command(host, NAME, SCHEMA, myCommandId, STATEIN, STATEOUT);
    }

    // Custom command entrypoints all follow this pattern:
    // the function name matches `NAME`, it accepts `CommandContext`, and it returns the next state bytes.
    function myCommand(
        CommandContext calldata c
    ) external payable onlyCommand(myCommandId, c.target) returns (bytes memory) {
        // Return encoded state for the next step. This example returns an empty BALANCES payload.
        bytes memory balances = "";
        return balances;
    }
}
