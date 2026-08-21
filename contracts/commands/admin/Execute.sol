// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Lanes, Specs} from "./Base.sol";
import {RawNodeCalls} from "../../core/Calls.sol";

using Executions for Execution;

/// @title ExecutePayable
/// @notice Admin command that forwards raw calldata to one or more target nodes.
/// Each CALL block specifies a target node ID, packed resources, and raw calldata payload.
/// Only callable by the admin account.
/// Unspent top-level `msg.value` is returned as a refund transaction.
abstract contract ExecutePayable is RawNodeCalls, AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("executePayable", Specs.Empty, Specs.Call, Specs.Empty, 0, Flags.AdminFunded);
    }

    /// @notice Execute each CALL block in the admin input.
    /// @param context Admin command context carrying the CALL input stream.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function executePayable(
        bytes calldata context
    ) external payable returns (bytes memory, bytes memory) {
        Execution memory exec = openAdminCommand(context, descriptor, 0);

        while (exec.more()) {
            (uint target, uint resources, bytes calldata data) = exec.unpackCall(Lanes.Input);
            rawCall(target, exec.useResourceValue(resources), data);
        }

        return closeCommand(exec);
    }
}
