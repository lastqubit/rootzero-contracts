// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when a guardian account status changes on a host.
abstract contract GuardianEvent is EventEmitter {
    string private constant ABI = "event Guardian(uint indexed host, bytes32 account, bool active)";

    /// @param host Host node ID where the guardian change occurred.
    /// @param account Guardian account ID.
    /// @param active True if the guardian is enabled, false if revoked.
    event Guardian(uint indexed host, bytes32 account, bool active);

    constructor() {
        emit EventAbi(ABI);
    }
}
