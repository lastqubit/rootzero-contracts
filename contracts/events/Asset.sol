// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Asset(uint indexed host, bytes32 name, bytes4 prefix, string format)";

abstract contract AssetEvent is EventEmitter {
    event Asset(uint indexed host, bytes32 name, bytes4 prefix, string format);

    constructor() {
        emit EventAbi(ABI);
    }
}
