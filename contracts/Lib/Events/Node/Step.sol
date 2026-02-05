// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Step(uint indexed host, uint id, uint gas, bytes4 selector, string signature)";

abstract contract StepEvent is EventEmitter {
    event Step(uint indexed host, uint id, uint gas, bytes4 selector, string signature);

    constructor() {
        emit Signature(ABI);
    }
}
