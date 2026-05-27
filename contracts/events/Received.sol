// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account receives an asset in a protocol operation.
abstract contract ReceivedEvent is EventEmitter {
    string private constant ABI = "event Received(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context)";

    /// @param account Account identifier that received the asset.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount received.
    /// @param context Operation context identifier associated with this receipt.
    /// The low 32 bits are the primary `Actions` hint; higher bits are reserved.
    event Received(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
