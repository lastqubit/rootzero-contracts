// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Collateral(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint access)";

// Query should be provided for the access command to get the exact colleteral.
abstract contract CollateralEvent is EventEmitter {
    event Collateral(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}
