// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Activity:Withdrawal(uint indexed account, uint indexed eid, uint id, uint amount)";

abstract contract WithdrawalEvent is EventEmitter {
    event Withdrawal(
        uint indexed account,
        uint indexed eid,
        uint id,
        uint amount
    );

    constructor() {
        emit EventDesc(ABI);
    }
}
