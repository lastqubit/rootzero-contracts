// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Fastish(uint indexed host, bytes32 account, uint deadline, uint value)";

abstract contract FastishEvent is EventEmitter {
    event Fastish(uint indexed host, bytes32 account, uint deadline, uint value);

    constructor() {
        emit EventAbi(ABI);
    }
}
