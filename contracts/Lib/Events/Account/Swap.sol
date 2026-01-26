// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Activity:Swap(uint indexed account, uint indexed eid, uint use, uint accept, uint amount, uint out)";

abstract contract SwapEvent is EventEmitter {
    event Swap(
        uint indexed account,
        uint indexed eid,
        uint use,
        uint accept,
        uint amount,
        uint out
    );

    constructor() {
        emit EventDesc(ABI);
    }
}
