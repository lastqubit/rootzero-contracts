// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortCalls} from "./Calls.sol";
import {ResolvedEvent} from "../events/Resolved.sol";
import {UndeliveredEvent} from "../events/Undelivered.sol";
import {Budget} from "../utils/Value.sol";

abstract contract RoutePayableHook {
    /// @notice Override to route an encoded payload through `portal`.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific destination resources. EVM adapters
    /// may interpret this as packed execution gas and destination value.
    /// @param payload Encoded payload ready for the transport layer.
    /// @param budget Source native-value budget available for transport
    /// fees and destination resource funding.
    function route(uint portal, uint resources, bytes memory payload, Budget memory budget) internal virtual;
}

abstract contract RecoverHook {
    /// @notice Override to recover a previously undelivered witness through `handler`.
    /// @param handler Port that should attempt recovery.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param value Native EVM value assigned to the recovery attempt.
    function recover(uint handler, bytes32 key, bytes calldata witness, uint128 value) internal virtual;
}

/// @title Portal
/// @notice Base contract for hosts that route payloads through portal adapters.
abstract contract Portal is PortCalls, RecoverHook, ResolvedEvent, UndeliveredEvent {
    error BadWitness();

    /// @dev Remote port used to handle messages delivered through this portal.
    uint private immutable port;

    mapping(bytes32 key => bytes32 digest) internal undelivered;

    /// @param handler Remote port used to handle messages delivered through this portal.
    constructor(uint handler) {
        port = handler;
    }

    /// @notice Try to deliver `message` to this portal's handler port.
    /// @dev Records `keccak256(message)` under `key` only when delivery fails.
    /// @param key Delivery/recovery lookup key.
    /// @param message Encoded port input to deliver.
    /// @param value Native EVM value assigned to the delivery attempt.
    function deliver(bytes32 key, bytes calldata message, uint128 value) internal {
        if (tryCallPort(port, value, message)) return;
        bytes32 digest = keccak256(message);
        undelivered[key] = digest;
        emit Undelivered(host, key, digest);
    }

    /// @notice Recover a previously undelivered witness through `handler`.
    /// @dev The witness must hash to the digest stored under `key`.
    /// @param handler Port that should attempt recovery.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param value Native EVM value assigned to the recovery attempt.
    function recover(uint handler, bytes32 key, bytes calldata witness, uint128 value) internal virtual override {
        if (keccak256(witness) != undelivered[key]) revert BadWitness();
        delete undelivered[key];
        callPort(handler, value, witness);
        emit Resolved(host, key);
    }
}
