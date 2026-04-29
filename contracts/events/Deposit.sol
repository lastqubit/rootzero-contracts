// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount)";

/// @notice Emitted when assets are deposited into an account.
abstract contract DepositEvent is EventEmitter {
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount deposited.
    event Deposit(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount);

    constructor() {
        emit EventAbi(ABI);
    }
}



