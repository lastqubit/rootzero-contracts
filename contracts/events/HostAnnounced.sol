// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event HostAnnounced(uint indexed host, uint blocknum, uint16 version, string namespace)";

abstract contract HostAnnouncedEvent is EventEmitter {
    event HostAnnounced(uint indexed host, uint blocknum, uint16 version, string namespace);

    constructor() {
        emit EventAbi(ABI);
    }
}
