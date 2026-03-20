// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Debt(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint mode, uint access)";

// Query should be provided for the access command to get the exact debt.
abstract contract DebtEvent is EventEmitter {
    event Debt(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint mode, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}
