// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account spends an asset in a protocol operation.
abstract contract SpentEvent is EventEmitter {
    string private constant ABI = "event Spent(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)";

    /// @param account Account identifier that spent the asset.
    /// @param asset Asset identifier.
    /// @param amount Amount spent.
    /// @param action Primary operation hint from `Actions`.
    /// @param context Reserved context value for future use.
    event Spent(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
