// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when a host-scoped commitment is updated.
abstract contract CommitmentEvent is EventEmitter {
    string private constant ABI = "event Commitment(uint indexed host, bytes32 key, bytes32 digest, uint status)";

    /// @param host Host node ID that manages the commitment.
    /// @param key Commitment lookup key.
    /// @param digest Committed digest. Zero may be used when clearing without revealing the previous digest.
    /// @param status Commitment status. Zero means cleared; nonzero means committed or application-defined.
    event Commitment(uint indexed host, bytes32 key, bytes32 digest, uint status);

    constructor() {
        emit EventAbi(ABI);
    }
}
