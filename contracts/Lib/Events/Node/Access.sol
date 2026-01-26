// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Access(uint indexed host, address caller, bool trusted)";
string constant TYPE = "access";

// callet uint id??
abstract contract AccessEvent is EventEmitter {
    event Access(uint indexed host, address caller, bool trusted);

    constructor() {
        emit EventDesc(false, TYPE, ABI);
    }
}