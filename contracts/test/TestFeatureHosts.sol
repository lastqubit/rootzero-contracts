// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Admins, CommandHost, Guardians} from "../core/Host.sol";

contract TestAdminsHost is CommandHost, Admins {
    constructor(uint cmdr) CommandHost(cmdr) {}
}

contract TestGuardiansHost is CommandHost, Guardians {
    constructor(uint cmdr) CommandHost(cmdr) {}
}
