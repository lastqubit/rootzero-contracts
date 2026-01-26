// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Discover(uint indexed host, address indexed origin, uint genesis, string name)";
string constant TYPE = "discover";

abstract contract DiscoverEvent is EventEmitter {
    event Discover(
        uint indexed host,
        address indexed origin,
        uint genesis,
        string name
    );

    constructor() {
        emit EventDesc(false, TYPE, ABI);
    }
}
