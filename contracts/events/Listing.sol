// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Listing(uint indexed host, bytes32 asset, bytes32 meta, bool active, bool created)";

abstract contract ListingEvent is EventEmitter {
    event Listing(uint indexed host, bytes32 asset, bytes32 meta, bool active, bool created);

    constructor() {
        emit EventAbi(ABI);
    }
}
