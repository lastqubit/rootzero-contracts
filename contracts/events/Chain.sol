// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a chain/domain node is announced.
abstract contract ChainEvent is EventEmitter {
    string private constant ABI = "event Chain(uint indexed chain, bytes32 native, uint commander, bytes32 admin, string name)";

    /// @param chain Chain node ID.
    /// @param native Native asset ID for the chain.
    /// @param commander Commander host node ID for the chain.
    /// @param admin Admin account for the commander host on the chain.
    /// @param name Chain or domain name.
    event Chain(uint indexed chain, bytes32 native, uint commander, bytes32 admin, string name);

    constructor() {
        emit EventAbi(ABI);
    }
}
