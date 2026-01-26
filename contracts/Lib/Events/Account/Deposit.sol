// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Activity:Deposit(uint indexed account, uint indexed eid, uint id, uint amount)";

abstract contract DepositEvent is EventEmitter {
    event Deposit(uint indexed account, uint indexed eid, uint id, uint amount);

    constructor() {
        emit EventDesc(ABI);
    }
}
