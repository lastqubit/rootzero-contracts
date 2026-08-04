// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Label
/// @notice Admin command that publishes namespaced labels for node IDs.
/// Each LABEL block in the input emits one `Labeled` event. Only callable by
/// the admin account.
abstract contract Label is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("label", Specs.Empty, Specs.Label, Specs.Empty, 0, false, true);
    }

    /// @notice Publish each LABEL block in the admin input.
    /// @param input LABEL block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function label(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (uint node, bytes32 namespace, string memory name) = exec.unpackLabel(Lanes.Input);
            emit Labeled(node, namespace, name);
        }

        return close(exec, account);
    }
}
