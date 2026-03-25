// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Balance(bytes32 indexed account, bytes32 asset, bytes32 meta, uint balance, int change, uint access)";

abstract contract BalanceEvent is EventEmitter {
    event Balance(bytes32 indexed account, bytes32 asset, bytes32 meta, uint balance, int change, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}
