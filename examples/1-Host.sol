// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 1: Minimal Host
//
// A Host is your application contract. Extending Host gives you:
//   - control command support (Authorize, Unauthorize, Execute)
//   - trusted caller enforcement for command entrypoints
//   - optional auto-registration with a rootzero discovery contract
//
// This is the smallest valid rootzero host - no commands yet.

import { Host } from "../contracts/Core.sol";

contract ExampleHost is Host {
    // rootzero - the trusted caller for command execution, typically a commander host.
    //            If rootzero is a contract, the host announces itself there on deployment.
    //            Pass address(0) for a self-managed host with no auto-registration.
    constructor(address rootzero) Host(rootzero) {}
}



