// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Withdrawal(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount)";

/// @notice Emitted when assets are withdrawn from an account.
abstract contract WithdrawalEvent is EventEmitter {
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount withdrawn.
    event Withdrawal(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount);

    constructor() {
        emit EventAbi(ABI);
    }
}



