// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Route(uint indexed endpoint, uint chain)";

abstract contract RouteEmitter is EventEmitter {
    event Route(uint indexed endpoint, uint chain);

    constructor() {
        emit EventDesc(ABI);
    }
}
