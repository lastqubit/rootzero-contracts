// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the input is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("authorize", Specs.Empty, Specs.Node, Specs.Empty, Flags.Admin);
    }

    /// @notice Return the registered AUTHORIZE command ID.
    function authorizeId() internal view returns (uint) {
        return id;
    }

    /// @notice Authorize each NODE block in the admin input.
    /// @param context Admin command context carrying the NODE input stream.
    /// @return Empty output state.
    /// @return Zero native budget credit.
    function authorize(
        bytes calldata context
    ) external returns (bytes memory, uint) {
        Execution memory exec = openAdminCommand(context, descriptor);

        while (exec.more()) {
            uint node = exec.unpackNode();
            setNode(node, true);
        }

        return exec.close();
    }
}
