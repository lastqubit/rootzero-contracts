// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Access(uint indexed host, uint node, bool trusted)";

abstract contract AccessEvent is EventEmitter {
    event Access(uint indexed host, uint node, bool trusted);

    constructor() {
        emit EventAbi(ABI);
    }
}
