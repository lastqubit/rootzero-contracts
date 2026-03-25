// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event Withdrawal(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid)";

abstract contract WithdrawalEvent is EventEmitter {
    event Withdrawal(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid);

    constructor() {
        emit EventAbi(ABI);
    }
}
