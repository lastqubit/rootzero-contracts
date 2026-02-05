// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Entry(uint indexed host, uint id, uint gas, string signature)";

abstract contract EntryEvent is EventEmitter {
    event Entry(uint indexed host, uint id, uint gas, string signature);

    constructor() {
        emit Signature(ABI);
    }
}
