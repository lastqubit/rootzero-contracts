// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";

// In a typical setup, `commander` and `discovery` both point to the Rush instance that coordinates and announces this host.
contract ExampleHost is Host {
    constructor(
        address commander,
        address discovery
    ) Host(commander, discovery, 1, "example") {}
}
