// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, Execution, Executions, Flags, Specs} from "./Base.sol";
import {FailedCall} from "../../core/Calls.sol";
import {Nodes} from "../../utils/Nodes.sol";

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

    /// @dev Execute arbitrary calldata while ignoring successful returndata.
    /// Returndata is copied only when needed to report a failed call.
    function callTarget(uint target, uint value, bytes calldata data) private {
        address addr = Nodes.addr(target);
        bytes4 selector = bytes4(data);
        bool success;
        bytes memory err;

        assembly ("memory-safe") {
            let scratch := mload(0x40)
            calldatacopy(scratch, data.offset, data.length)
            success := call(gas(), addr, value, scratch, data.length, 0, 0)

            if iszero(success) {
                let size := returndatasize()
                err := scratch
                mstore(err, size)
                returndatacopy(add(err, 0x20), 0, size)
                mstore(add(add(err, 0x20), size), 0)
                mstore(0x40, and(add(add(add(err, 0x20), size), 0x1f), not(0x1f)))
            }
        }

        if (!success) revert FailedCall(addr, selector, err);
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
            callTarget(target, exec.useResourceValue(resources), data);
        }

        return exec.close();
    }
}
