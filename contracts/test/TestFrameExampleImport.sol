// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

// Test-only import shim so Hardhat compiles the frame example, which lives
// outside the default `contracts/` source tree.
import "../../examples/7-Frame.sol";

contract TestFrameExampleHost is ExampleHost {
    constructor(address rootzero) ExampleHost(rootzero) {}
}
