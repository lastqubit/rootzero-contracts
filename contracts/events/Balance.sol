// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Balance(bytes32 indexed account, bytes32 asset, bytes32 meta, uint balance, int change, uint access)";

/// @notice Emitted when an account balance changes.
abstract contract BalanceEvent is EventEmitter {
    /// @param account Account identifier whose balance changed.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param balance New balance after the change.
    /// @param change Signed delta applied to the balance (positive = credit, negative = debit).
    /// @param access Command ID or context identifier associated with this change.
    event Balance(bytes32 indexed account, bytes32 asset, bytes32 meta, uint balance, int change, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}



