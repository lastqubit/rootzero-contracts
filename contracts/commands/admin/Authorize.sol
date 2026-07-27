// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Keys, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    uint private immutable descriptor;
    uint internal immutable authorizeId;

    constructor() {
        (authorizeId, descriptor) = command("authorize", Specs.Empty, Specs.Node, Specs.Empty, 0, false, true);
    }

    /// @notice Authorize each NODE block in the admin request.
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

        return closeCommand(exec, account);
    }
}
