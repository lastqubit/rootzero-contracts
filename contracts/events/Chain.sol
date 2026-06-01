// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a chain/domain node is announced.
abstract contract ChainEvent is EventEmitter {
    string private constant ABI = "event Chain(uint indexed chain, string name)";

    /// @param chain Chain node ID.
    /// @param name Chain or domain name.
    event Chain(uint indexed chain, string name);

    constructor() {
        emit EventAbi(ABI);
    }
}
