// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, Execution, Executions, Flags, Lanes, Specs } from "./Base.sol";
import { GuardianAccess } from "../../core/Access.sol";
using Executions for Execution;

/// @title Dismiss
/// @notice Admin command that revokes guardian status from a list of account IDs.
/// Each USER ACCOUNT block in the input loses the guardian role on the host.
/// Only callable by the admin account.
abstract contract Dismiss is GuardianAccess, AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("dismiss", Specs.Empty, Specs.Account, Specs.Empty, 0, Flags.Admin);
    }

    /// @notice Dismiss each user ACCOUNT block in the admin input from guardian status.
    /// @param input ACCOUNT block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function dismiss(
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openCommand(state, input, descriptor, 0);

        while (exec.more()) {
            bytes32 guardian = exec.unpackAccount(Lanes.Input);
            setGuardian(guardian, false);
        }

        return close(exec, account);
    }
}
