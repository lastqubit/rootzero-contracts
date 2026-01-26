// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Token(uint indexed host, address addr, uint id, bool supported)";

abstract contract TokenEmitter is EventEmitter {
    event Token(uint indexed host, address addr, uint id, bool supported);

    constructor() {
        emit EventDesc(ABI);
    }
}
