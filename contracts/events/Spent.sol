// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account spends an asset in a protocol operation.
abstract contract SpentEvent is EventEmitter {
    string private constant ABI = "event Spent(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context)";

    /// @param account Account identifier that spent the asset.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount spent.
    /// @param context Operation context identifier associated with this spend.
    event Spent(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
