// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

// Example 1: Minimal Host
//
// A Host is your application contract. Extending Host gives you:
//   - admin command support (Authorize, Unauthorize, Relocate)
//   - trusted Rush runtime enforcement
//   - optional auto-registration with a Rush discovery contract
//
// This is the smallest valid Rush host — no commands yet.

import {Host} from "../contracts/Core.sol";

contract ExampleHost is Host {
    // rush      — the trusted Rush runtime. Only calls from this address are accepted by commands.
    //             If rush is a contract, the host announces itself there on deployment.
    //             Pass address(0) for a self-managed host with no auto-registration.
    // 1         — host version, used for discovery and upgrade tracking.
    // "example" — host namespace, used to group related hosts in discovery.
    constructor(address rush) Host(rush, 1, "example") {}
}
