// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title EventEmitter
/// @notice Base contract that publishes an ABI string for each event emitted by a contract.
/// Each event mixin emits `EventAbi` in its constructor so off-chain indexers can
/// discover the full event ABI without relying on external artifact files.
abstract contract EventEmitter {
    /// @dev Emitted once per event type at deployment time with the full ABI string.
    event EventAbi(string abi);
}



