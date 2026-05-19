// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {HostDiscovery} from "../core/Host.sol";
import {TestHost} from "./TestHost.sol";

contract TestCommanderHost is TestHost, HostDiscovery {
    constructor(address rootzero) TestHost(rootzero) {}
}
