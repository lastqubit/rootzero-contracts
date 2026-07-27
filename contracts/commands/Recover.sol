// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions, CommandBase, Keys, Lanes, Specs} from "./Base.sol";

using Executions for Execution;

abstract contract RecoverHook {
    /// @notice Override to recover a witness through `handler`.
    /// @param handler Port that should attempt recovery.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param value Native EVM value assigned to the recovery attempt.
    function recover(uint handler, bytes32 key, bytes calldata witness, uint128 value) internal virtual;
}

/// @title RecoverPayable
/// @notice Command that forwards recover request blocks to a virtual hook.
/// Recovery is witness-driven: the command account pays and receives leftover
/// value settlement, but the recovered subject is defined by each witness.
/// Produces no output state.
abstract contract RecoverPayable is CommandBase, RecoverHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("recoverPayable", Specs.Empty, Specs.Recover, Specs.Empty, 0, true, false);
    }

    /// @notice Recover each recover block in the command request.
    /// @param input RECOVER block stream.
    /// @return Empty output state.
    /// @return Remaining native value as a refund transaction stream.
    function recoverPayable(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (uint handler, uint resources, bytes32 key, bytes calldata witness) = exec.unpackRecover(Lanes.Input);
            recover(handler, key, witness, exec.useValue(resources));
        }

        return closeCommand(exec, account);
    }
}
