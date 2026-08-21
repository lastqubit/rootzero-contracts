// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Lanes, Specs} from "./Base.sol";
using Executions for Execution;

/// @title Annotate
/// @notice Admin command that attaches encoded annotation block streams to entities.
/// Each ANNOTATION block in the input emits one `Annotation` event. Only callable
/// by the admin account.
abstract contract Annotate is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("annotate", Specs.Empty, Specs.Annotation, Specs.Empty, 0, Flags.Admin);
    }

    /// @notice Publish each ANNOTATION block in the admin input.
    /// @param context Admin command context carrying the ANNOTATION input stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function annotate(
        bytes calldata context
    ) external returns (bytes memory, bytes memory) {
        Execution memory exec = openAdminCommand(context, descriptor, 0);

        while (exec.more()) {
            (uint entity, bytes calldata data) = exec.unpackAnnotation(Lanes.Input);
            emit Annotation(entity, data);
        }

        return closeCommand(exec);
    }
}
