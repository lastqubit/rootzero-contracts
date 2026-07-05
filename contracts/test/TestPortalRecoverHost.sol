// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {RecoverPayable} from "../commands/Recover.sol";
import {Host} from "../core/Host.sol";
import {Portal} from "../core/Portal.sol";

contract TestPortalRecoverHost is Host, Portal, RecoverPayable {
    constructor(address rootzero, uint handler) Host(rootzero) Portal(handler) {}
}
