// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {PortBase} from "./Base.sol";
import {AllowanceHook} from "../commands/admin/Allowance.sol";
import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";

using Executions for Execution;

/// @title PortAllowance
/// @notice Port that lets a trusted peer host request or refresh its own allowance.
/// Each AMOUNT block in the request is scoped to the peer host and passed to the
/// shared allowance hook as a host-scoped allowance. Restricted to trusted peers.
abstract contract PortAllowance is PortBase, AllowanceHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = port("portAllowance", Specs.Amount, Specs.Empty, 0, false);
    }

    /// @notice Execute the allowance port call.
    /// @param data AMOUNT block stream requested by the trusted peer.
    /// @return Empty response bytes.
    function portAllowance(bytes calldata data) external onlyPeer returns (bytes memory) {
        Execution memory exec = openInput(data, descriptor, 0);
        uint peer = caller();

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            allowance(peer, asset, amount);
        }
        return "";
    }
}
