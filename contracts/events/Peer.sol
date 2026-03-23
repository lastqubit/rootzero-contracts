// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Peer(uint indexed host, string name, string schema, uint pid)";

abstract contract PeerEvent is EventEmitter {
    event Peer(uint indexed host, string name, string schema, uint pid);

    constructor() {
        emit EventAbi(ABI);
    }
}
