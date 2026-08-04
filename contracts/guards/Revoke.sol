// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {GuardBase} from "./Base.sol";
import {Specs} from "../Codec.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
using Executions for Execution;

/// @title Revoke
/// @notice Guardian action that quickly revokes authorization from a list of node IDs.
/// Each NODE block in the input is deauthorized on the host.
/// Only callable by active guardian addresses.
abstract contract Revoke is GuardBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = guard("revoke", Specs.Node);
    }

    /// @notice Revoke every NODE block in `input` as the active guardian.
    function revoke(bytes calldata input) external onlyGuardian {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            uint node = exec.unpackNode(Lanes.Input);
            setNode(node, false);
        }

    }
}
