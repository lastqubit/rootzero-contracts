// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {GuardBase} from "./Base.sol";
import {Keys, Specs} from "../Cursors.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
using Executions for Execution;

/// @title Revoke
/// @notice Guardian action that quickly revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by active guardian addresses.
abstract contract Revoke is GuardBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = guard("revoke", Specs.Node, 0);
    }

    function revoke(bytes calldata request) external onlyGuardian {
        Execution memory exec = openInput(request, descriptor, 0);

        while (exec.more()) {
            uint node = exec.unpackNode(Lanes.Input);
            setNode(node, false);
        }

    }
}
