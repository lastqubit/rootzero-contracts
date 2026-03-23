// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 2: Built-In Command (DebitAccountToBalance)
//
// The easiest way to add a command is to mix in a built-in command module and
// implement its hook. The module handles block parsing and response encoding;
// you only write the business logic specific to your app.
//
// DebitAccountToBalance:
//   - reads one or more AMOUNT blocks from `request`
//   - calls `debitAccount` for each (your hook — deduct from your storage)
//   - returns matching BALANCE blocks as the response

import {Host} from "../contracts/Core.sol";
import {DebitAccountToBalance} from "../contracts/Commands.sol";
import {ensureAssetRef} from "../contracts/Utils.sol";

contract ExampleHost is Host, DebitAccountToBalance {
    // Internal balance ledger: account → asset key → amount
    mapping(bytes32 account => mapping(bytes32 assetRef => uint amount)) internal balances;

    constructor(address rush) Host(rush, 1, "example") {}

    // debitAccount is the hook DebitAccountToBalance calls for each AMOUNT block.
    // Implement this with whatever storage your app uses.
    function debitAccount(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal override {
        // ensureAssetRef combines asset + meta into a single composite storage key.
        bytes32 ref = ensureAssetRef(asset, meta);
        balances[account][ref] -= amount;
    }
}
