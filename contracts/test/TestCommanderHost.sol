// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {TestHost} from "./TestHost.sol";

contract TestCommanderHost is TestHost {
    constructor(uint rootzero) TestHost(rootzero) {}
}
