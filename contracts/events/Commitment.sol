// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account-scoped commitment is updated.
abstract contract CommitmentEvent is EventEmitter {
    string private constant ABI = "event Commitment(bytes32 indexed account, bytes32 key, bytes32 digest, uint status)";

    /// @param account Account associated with the commitment.
    /// @param key Commitment lookup key.
    /// @param digest Committed digest. Zero may be used when clearing without revealing the previous digest.
    /// @param status Commitment status. Zero means cleared; nonzero means committed or application-defined.
    event Commitment(bytes32 indexed account, bytes32 key, bytes32 digest, uint status);

    constructor() {
        emit EventAbi(ABI);
    }
}
