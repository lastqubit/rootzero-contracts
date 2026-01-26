// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Discover(uint indexed node, address indexed origin, uint block0, string name)";

abstract contract DiscoverEvent is EventEmitter {
    event Discover(uint indexed node, address indexed origin, uint block0, string name);

    constructor() {
        emit EventDesc(ABI);
    }
}
