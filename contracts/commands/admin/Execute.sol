// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Specs} from "./Base.sol";
import {rawCall} from "../../core/Calls.sol";

using Executions for Execution;

/// @title ExecutePayable
/// @notice Admin command that forwards raw calldata to one or more target nodes.
/// Each CALL block specifies a target node ID, opaque packed resources, and raw
/// calldata payload. Packed resources are converted to plain native value only
/// through `useResourceValue`.
/// Only callable by the admin account.
/// Unspent top-level `msg.value` is returned as native budget credit.
abstract contract ExecutePayable is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("executePayable", Specs.Empty, Specs.Call, Specs.Empty, Flags.AdminFunded);
    }

    /// @notice Execute each CALL block in the admin input.
    /// @param context Admin command context carrying the CALL input stream.
    /// @return Empty output state.
    /// @return Native value to add to the caller's budget.
    function executePayable(
        bytes calldata context
    ) external payable returns (bytes memory, uint) {
        Execution memory exec = openAdminCommand(context, descriptor);

        while (exec.more()) {
            (uint target, uint resources, bytes calldata data) = exec.unpackCall();
            rawCall(target, exec.useResourceValue(resources), data);
        }

        return exec.close();
    }
}
