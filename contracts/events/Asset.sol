// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when assets enter a host.
abstract contract AssetEnteredEvent is EventEmitter {
    string private constant ABI = "event AssetEntered(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount)";

    /// @param account Account identifier the assets entered for.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount that entered.
    event AssetEntered(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount);

    constructor() {
        emit EventAbi(ABI);
    }
}

/// @notice Emitted when assets leave a host.
abstract contract AssetExitedEvent is EventEmitter {
    string private constant ABI = "event AssetExited(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount)";

    /// @param account Account identifier the assets exited from.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount that exited.
    event AssetExited(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount);

    constructor() {
        emit EventAbi(ABI);
    }
}



