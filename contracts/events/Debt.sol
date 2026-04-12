// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Debt(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint mode, uint access)";

/// @notice Emitted when an account's debt position changes.
/// Off-chain indexers should query the access command to retrieve precise debt details.
abstract contract DebtEvent is EventEmitter {
    /// @param account Account identifier that holds the debt.
    /// @param asset Asset identifier of the debt.
    /// @param meta Asset metadata slot.
    /// @param amount Current debt amount.
    /// @param mode Debt mode or type discriminant (implementation-defined).
    /// @param access Command ID or context identifier associated with this change.
    event Debt(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint mode, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}



