// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Test-only import shim so Hardhat compiles the transaction-output example,
// which lives outside the default `contracts/` source tree.
import {ExampleHost} from "../../examples/8-Transactions.sol";

contract TestTransactionsExampleHost is ExampleHost {
    constructor(uint rootzero) ExampleHost(rootzero) {}
}
