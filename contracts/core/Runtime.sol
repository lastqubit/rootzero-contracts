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

    /// @dev Commander host ID. Defaults to this contract's host ID when self-managed.
    uint internal immutable commander;

    /// @dev Native address embedded in `commander`, resolved once at construction.
    address internal immutable commanderAddr;

    /// @param cmdr Local host ID of the commander, or zero to make this runtime self-managed.
    constructor(uint cmdr) {
        commander = cmdr == 0 ? host : cmdr;
        commanderAddr = Nodes.hostAddr(commander);
    }
}
