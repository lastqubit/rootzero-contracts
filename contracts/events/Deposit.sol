// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid)";

abstract contract DepositEvent is EventEmitter {
    event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid);

    constructor() {
        emit EventAbi(ABI);
    }
}
