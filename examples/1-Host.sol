// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Host} from "../contracts/Core.sol";

// In a typical setup, the Rush instance both coordinates and announces this host.
contract ExampleHost is Host {
    constructor(address rush) Host(rush, 1, "example") {}
}
