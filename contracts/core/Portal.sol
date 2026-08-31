// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {tryRawCallCopy} from "./Calls.sol";
import {CommanderAccess} from "./Access.sol";
import {ResolvedEvent} from "../events/Resolved.sol";
import {UnresolvedEvent} from "../events/Unresolved.sol";
import {PortPipePayableSelector} from "../ports/Pipe.sol";

/// @notice Hook for forwarding a recoverable message through a transport boundary.
abstract contract ForwardHook {
    /// @notice Attempt to forward `message`, recording or returning its failure digest as needed.
    /// @param key Forwarding and recovery lookup key.
    /// @param message Encoded message to forward.
    /// @param value Native EVM value assigned to the forwarding attempt.
    /// @return miss Message digest retained for recovery when forwarding fails; zero on success.
    function forward(bytes32 key, bytes calldata message, uint value) internal virtual returns (bytes32 miss);
}

/// @title Portal
/// @notice Base contract that forwards incoming contexts to its commander's pipeline.
abstract contract Portal is ForwardHook, CommanderAccess, UnresolvedEvent, ResolvedEvent {
    error BadWitness();

    mapping(bytes32 key => bytes32 digest) internal unresolved;

    /// @notice Try to forward `message` to the commander's payable pipeline port.
    /// @dev Records and returns `keccak256(message)` under `key` only when forwarding fails.
    /// @param key Forwarding/recovery lookup key.
    /// @param message Encoded CONTEXT block stream to forward.
    /// @param value Native EVM value assigned to the forwarding attempt.
    /// @return miss Message digest recorded for recovery when forwarding fails; zero on success.
    function forward(bytes32 key, bytes calldata message, uint value) internal override returns (bytes32 miss) {
        if (tryRawCallCopy(PortPipePayableSelector, commanderAddr, value, message)) return bytes32(0);

        miss = keccak256(message);
        unresolved[key] = miss;
        emit Unresolved(host, key, miss);
    }

    /// @notice Validate and consume a previously unresolved witness.
    /// @dev The witness must hash to the digest stored under `key`.
    /// If a later recovery operation reverts, this deletion is rolled back with it.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    function resolve(bytes32 key, bytes calldata witness) internal {
        if (unresolved[key] != keccak256(witness)) revert BadWitness();

        delete unresolved[key];
    }
}
