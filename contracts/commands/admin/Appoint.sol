// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, Execution, Executions, Flags, Lanes, Specs } from "./Base.sol";
import { GuardianAccess } from "../../core/Access.sol";
using Executions for Execution;

/// @title Appoint
/// @notice Admin command that grants guardian status to a list of account IDs.
/// Each USER ACCOUNT block in the input is assigned the guardian role on the host.
/// Only callable by the admin account.
abstract contract Appoint is GuardianAccess, AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("appoint", Specs.Empty, Specs.Account, Specs.Empty, 0, Flags.Admin);
    }

    /// @notice Appoint each user ACCOUNT block in the admin input as a guardian.
    /// @param context Admin command context carrying the ACCOUNT input stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function appoint(
        bytes calldata context
    ) external returns (bytes memory, bytes memory) {
        Execution memory exec = openAdminCommand(context, descriptor, 0);

        while (exec.more()) {
            bytes32 guardian = exec.unpackAccount(Lanes.Input);
            setGuardian(guardian, true);
        }

        return closeCommand(exec);
    }
}
