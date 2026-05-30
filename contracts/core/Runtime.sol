// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Assets} from "../utils/Assets.sol";
import {Ids} from "../utils/Ids.sol";

/// @title Runtime
/// @notice Shared runtime for host identity and native value identity.
abstract contract Runtime {
    /// @dev This contract's host node ID, set to `Ids.toHost(address(this))` at construction.
    uint public immutable host = Ids.toHost(address(this));
    /// @dev Asset ID for the native chain value (ETH), bound to the current chain at deployment.
    bytes32 internal immutable valueAsset = Assets.toValue();
}
