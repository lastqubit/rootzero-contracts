// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Governed(uint indexed host, uint deadline, uint value)";

/// @notice Emitted when a governance action is recorded on a host.
abstract contract GovernedEvent is EventEmitter {
    /// @param host Host node ID where the governance action occurred.
    /// @param deadline Expiry timestamp of the governance action.
    /// @param value Native value associated with the action.
    event Governed(uint indexed host, uint deadline, uint value);

    constructor() {
        emit EventAbi(ABI);
    }
}



