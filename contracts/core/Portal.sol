// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortCalls} from "./Calls.sol";
import {NodeAccess} from "./Access.sol";
import {ResolvedEvent} from "../events/Resolved.sol";
import {UnresolvedEvent} from "../events/Unresolved.sol";

/// @title Portal
/// @notice Base contract for hosts that route payloads through portal adapters.
abstract contract Portal is PortCalls, NodeAccess, UnresolvedEvent, ResolvedEvent {
    error BadWitness();

    mapping(bytes32 key => bytes32 digest) internal unresolved;

    /// @notice Try to forward `message` to `port`.
    /// @dev Records and returns `keccak256(message)` under `key` only when forwarding fails.
    /// @param port Port that should handle the forwarded message.
    /// @param key Forwarding/recovery lookup key.
    /// @param message Encoded port input to forward.
    /// @param value Native EVM value assigned to the forwarding attempt.
    /// @return miss Message digest recorded for recovery when forwarding fails; zero on success.
    function forward(uint port, bytes32 key, bytes calldata message, uint value) internal returns (bytes32 miss) {
        if (tryCallPortCopy(port, value, message)) return bytes32(0);

        miss = keccak256(message);
        unresolved[key] = miss;
    }

    /// @notice Resolve a previously unresolved witness through `port`.
    /// @dev The witness must hash to the digest stored under `key`.
    /// @param port Port that should attempt recovery.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param value Native EVM value assigned to the resolution attempt.
    function resolve(uint port, bytes32 key, bytes calldata witness, uint value) internal virtual {
        if (unresolved[key] != keccak256(witness)) revert BadWitness();

        delete unresolved[key];
        callPortCopy(port, value, witness);
    }
}
