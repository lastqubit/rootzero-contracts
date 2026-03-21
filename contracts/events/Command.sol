// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Command(uint indexed host, string name, string schema, uint cid, uint8 stateIn, uint8 stateOut)";

abstract contract CommandEvent is EventEmitter {
    event Command(uint indexed host, string name, string schema, uint cid, uint8 stateIn, uint8 stateOut);

    constructor() {
        emit EventAbi(ABI);
    }
}
