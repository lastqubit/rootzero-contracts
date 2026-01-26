// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Balance(address indexed account, uint indexed eid, uint id, uint balance, uint change)";
string constant TYPE = "balance";

// check order on emit Balance
abstract contract BalanceEvent is EventEmitter {
    event Balance(
        uint indexed account,
        uint indexed eid,
        uint id,
        uint balance,
        uint change
    );

    constructor() {
        emit EventDesc(false, TYPE, ABI);
    }
}
