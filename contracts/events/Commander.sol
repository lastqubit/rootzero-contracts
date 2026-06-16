// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a commander is announced for a chain/domain.
abstract contract CommanderEvent is EventEmitter {
    string private constant ABI = "event Commander(uint indexed host, uint chain, bytes32 native, bytes32 admin)";

    /// @param host Commander host node ID for the chain.
    /// @param chain Chain/domain node ID.
    /// @param native Native asset ID for the chain.
    /// @param admin Admin account for the commander host on the chain.
    event Commander(uint indexed host, uint chain, bytes32 native, bytes32 admin);

    constructor() {
        emit EventAbi(ABI);
    }
}
