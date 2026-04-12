// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid)";

/// @notice Emitted when assets are deposited into an account.
abstract contract DepositEvent is EventEmitter {
    /// @param account Recipient account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount deposited.
    /// @param cid Command ID that triggered the deposit.
    event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint cid);

    constructor() {
        emit EventAbi(ABI);
    }
}



