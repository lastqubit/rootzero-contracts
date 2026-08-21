// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Unauthorize
/// @notice Admin command that revokes authorization from a list of node IDs.
/// Each NODE block in the input is deauthorized on the host.
/// Only callable by the admin account.
abstract contract Unauthorize is AdminBase {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("unauthorize", Specs.Empty, Specs.Node, Specs.Empty, 0, Flags.Admin);
    }

    /// @notice Return the registered UNAUTHORIZE command ID.
    function unauthorizeId() internal view returns (uint) {
        return id;
    }

    /// @notice Unauthorize each NODE block in the admin input.
    /// @param context Admin command context carrying the NODE input stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function unauthorize(
        bytes calldata context
    ) external returns (bytes memory, bytes memory) {
        Execution memory exec = openAdminCommand(context, descriptor, 0);

        while (exec.more()) {
            uint node = exec.unpackNode(Lanes.Input);
            setNode(node, false);
        }

        return closeCommand(exec);
    }
}
