// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Annotate
/// @notice Admin command that attaches encoded annotation block streams to entities.
/// Each ANNOTATION block in the input emits one `Annotation` event. Only callable
/// by the admin account.
abstract contract Annotate is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("annotate", Specs.Empty, Specs.Annotation, Specs.Empty, 0, false, true);
    }

    /// @notice Publish each ANNOTATION block in the admin input.
    /// @param input ANNOTATION block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function annotate(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (uint entity, bytes calldata data) = exec.unpackAnnotation(Lanes.Input);
            emit Annotation(entity, data);
        }

        return close(exec, account);
    }
}
