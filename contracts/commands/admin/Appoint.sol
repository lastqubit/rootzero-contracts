// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, Execution, Executions, Keys, Lanes, Specs } from "./Base.sol";
using Executions for Execution;

/// @title Appoint
/// @notice Admin command that grants guardian status to a list of account IDs.
/// Each ACCOUNT block in the request is enabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Appoint is AdminBase {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("appoint", Specs.Empty, Specs.Account, Specs.Empty, 0, false, true);
    }

    /// @notice Appoint each ACCOUNT block in the admin request as a guardian.
    /// @param input ACCOUNT block stream.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function appoint(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyAdmin(account) returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            bytes32 guardian = exec.unpackAccount(Lanes.Input);
            setGuardian(guardian, true);
        }

        return closeCommand(exec, account);
    }
}
