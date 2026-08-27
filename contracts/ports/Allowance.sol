// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions} from "../execution/Execution.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that handle allowance requests from peers.
abstract contract RequestAllowanceHook {
    /// @notice Override to handle one allowance request from a peer host.
    /// @dev The implementation is responsible for validating the request and
    /// deciding what allowance, if any, to grant.
    /// @param peer Peer host node ID requesting the allowance.
    /// @param asset Asset identifier supplied by the peer.
    /// @param amount Allowance amount requested in the asset's native units.
    function requestAllowance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title RequestAllowancePort
/// @notice Port that lets trusted peers request their own asset allowances.
/// Each AMOUNT block is scoped to the caller and passed unchanged to
/// `requestAllowance(peer, asset, amount)`.
abstract contract RequestAllowancePort is PortBase, RequestAllowanceHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portRequestAllowance", Specs.Amount, Specs.Empty, 0);
    }

    /// @notice Request asset allowances for the calling peer.
    /// @param data AMOUNT block stream supplied by the trusted peer.
    /// @return Empty response bytes.
    function portRequestAllowance(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor);
        uint peer = caller();

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount();
            requestAllowance(peer, asset, amount);
        }

        return "";
    }
}
