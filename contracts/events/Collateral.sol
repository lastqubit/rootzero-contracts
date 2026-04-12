// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Collateral(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint access)";

/// @notice Emitted when an account's collateral position changes.
/// Off-chain indexers should query the access command to retrieve the precise collateral details.
abstract contract CollateralEvent is EventEmitter {
    /// @param account Account identifier that holds the collateral.
    /// @param asset Asset identifier of the collateral.
    /// @param meta Asset metadata slot.
    /// @param amount Current collateral amount.
    /// @param access Command ID or context identifier associated with this change.
    event Collateral(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint access);

    constructor() {
        emit EventAbi(ABI);
    }
}



