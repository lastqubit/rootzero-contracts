// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Assets} from "../utils/Assets.sol";
import {Nodes} from "../utils/Nodes.sol";

/// @title NativeAsset
/// @notice Shared native asset identity for host helpers.
abstract contract NativeAsset {
    /// @dev Asset ID for the native chain coin/token, bound to the current chain at deployment.
    bytes32 internal immutable nativeAsset = Assets.toNative();
}

/// @title Runtime
/// @notice Shared runtime for host identity and native asset identity.
abstract contract Runtime is NativeAsset {
    /// @dev This contract's host node ID, set to `Nodes.toHost(address(this))` at construction.
    uint public immutable host = Nodes.toHost(address(this));
}
