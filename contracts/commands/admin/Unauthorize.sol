// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Keys, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Unauthorize
/// @notice Admin command that revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by the admin account.
abstract contract Unauthorize is AdminBase {
    uint private immutable descriptor;
    uint internal immutable unauthorizeId;

    constructor() {
        (unauthorizeId, descriptor) =
            command("unauthorize", Specs.Empty, Specs.Node, Specs.Empty, 0, false, true);
    }

    /// @notice Unauthorize each NODE block in the admin request.
    /// @param input NODE block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function unauthorize(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            uint node = exec.unpackNode(Lanes.Input);
            setNode(node, false);
        }

        return closeCommand(exec, account);
    }
}
