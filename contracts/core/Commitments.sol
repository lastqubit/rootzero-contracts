// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommitmentEvent} from "../events/Commitment.sol";

/// @title Commitments
/// @notice On-chain registry for digest commitments.
abstract contract Commitments is CommitmentEvent {
    /// @dev key -> committed digest.
    mapping(bytes32 key => bytes32 digest) internal commitments;

    /// @notice Clear the commitment under `key` and return the removed digest.
    /// @param key Commitment lookup key.
    /// @return digest Removed digest.
    function uncommit(bytes32 key) internal returns (bytes32 digest) {
        digest = commitments[key];
        delete commitments[key];
    }
}
