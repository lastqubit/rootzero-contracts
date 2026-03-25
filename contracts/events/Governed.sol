// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Governed(uint indexed host, uint deadline, uint value)";

abstract contract GovernedEvent is EventEmitter {
    event Governed(uint indexed host, uint deadline, uint value);

    constructor() {
        emit EventAbi(ABI);
    }
}
