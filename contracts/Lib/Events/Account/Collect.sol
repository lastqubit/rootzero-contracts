// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Collect(uint indexed account, uint indexed eid, uint id, uint amount)";
string constant TYPE = "collect";

abstract contract CollectEvent is EventEmitter {
    event Collect(uint indexed account, uint indexed eid, uint id, uint amount);

    constructor() {
        emit EventDesc(false, TYPE, ABI);
    }
}
