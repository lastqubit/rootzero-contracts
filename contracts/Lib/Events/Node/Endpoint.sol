// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "../Emitter.sol";

string constant ABI = "event Endpoint(uint indexed host, uint id, uint gas, string abi, string params)";

// abi contains address signer for signed params

// abi not NEEDED ??

abstract contract EndpointEvent is EventEmitter {
    event Endpoint(uint indexed host, uint id, uint gas, string abi, string params);

    constructor() {
        emit EventDesc(ABI);
    }
}
