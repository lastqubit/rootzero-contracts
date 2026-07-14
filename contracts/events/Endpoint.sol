// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @title EndpointEvent
/// @notice Emitted during host deployment to publish a callable endpoint descriptor.
abstract contract EndpointEvent is EventEmitter {
    string private constant ABI = "event Endpoint(uint indexed host, uint id, bytes32 descriptor)";

    /// @param host Host node ID that exposes the endpoint.
    /// @param id Endpoint node ID.
    /// @param descriptor Packed endpoint lane metadata and flags.
    event Endpoint(uint indexed host, uint id, bytes32 descriptor);

    constructor() {
        emit EventAbi(ABI);
    }
}
