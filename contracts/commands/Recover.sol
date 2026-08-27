// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Flags, Specs} from "./Base.sol";

using Executions for Execution;

/// @notice Hook implemented by hosts that recover previously unresolved payloads.
abstract contract RecoverPayableHook {
    /// @notice Override to recover a witness through `handler`.
    /// @param handler Port that should attempt recovery.
    /// @param resources Chain-specific resources assigned to the recovery attempt.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param funds Shared execution containing the source value budget.
    function recover(
        uint handler,
        uint resources,
        bytes32 key,
        bytes calldata witness,
        Execution memory funds
    ) internal virtual;
}

/// @title RecoverPayable
/// @notice Command that forwards recover input blocks to a virtual hook.
/// Recovery is witness-driven: the command account pays and receives leftover
/// value posting, but the recovered subject is defined by each witness.
/// Produces no output state.
abstract contract RecoverPayable is CommandBase, RecoverPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("recoverPayable", Specs.Empty, Specs.Recover, Specs.Empty, Flags.Funded);
    }

    /// @notice Recover each recover block in the command input.
    /// @param context Command context carrying the RECOVER input stream.
    /// @return Empty output state.
    /// @return Native value to add to the caller's budget.
    function recoverPayable(
        bytes calldata context
    ) external payable onlyCommand returns (bytes memory, uint) {
        Execution memory exec = openCommand(context, descriptor);

        while (exec.more()) {
            (uint handler, uint resources, bytes32 key, bytes calldata witness) = exec.unpackRecover();
            recover(handler, resources, key, witness, exec);
        }

        return exec.close();
    }
}
