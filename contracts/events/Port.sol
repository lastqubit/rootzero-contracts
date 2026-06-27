// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted by hosts to advertise callable peer-facing ports.
abstract contract PortEvent is EventEmitter {
    string private constant ABI =
        "event Port(uint indexed host, uint id, bytes32 shape, string request, string response, bool funded)";

    /// @param host Host node ID that exposes the port.
    /// @param id Port node ID.
    /// @param shape Block shape/version descriptor.
    /// @param request Human-readable request schema.
    /// @param response Human-readable response schema.
    /// @param funded True if the port accepts native value.
    event Port(uint indexed host, uint id, bytes32 shape, string request, string response, bool funded);

    constructor() {
        emit EventAbi(ABI);
    }
}
