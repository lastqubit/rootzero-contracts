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
    /// @param input CALL block stream.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function executePayable(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external payable onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            (uint target, uint resources, bytes calldata data) = exec.unpackCall(Lanes.Input);
            rawCall(target, exec.useResourceValue(resources), data);
        }

        return close(exec, account);
    }
}
