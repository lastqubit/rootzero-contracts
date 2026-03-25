// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Quote(uint indexed host, uint cid, string schema)";

abstract contract QuoteEvent is EventEmitter {
    event Quote(uint indexed host, uint cid, string schema);

    constructor() {
        emit EventAbi(ABI);
    }
}
