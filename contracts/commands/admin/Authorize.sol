// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the input is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    uint private immutable descriptor;
    uint private immutable id;

    constructor() {
        (id, descriptor) = command("authorize", Specs.Empty, Specs.Node, Specs.Empty, 0, false, true);
    }

    /// @notice Return the registered AUTHORIZE command ID.
    function authorizeId() internal view returns (uint) {
        return id;
    }

    /// @notice Authorize each NODE block in the admin input.
    /// @param input NODE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function authorize(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            uint node = exec.unpackNode(Lanes.Input);
            setNode(node, true);
        }

        return close(exec, account);
    }
}
