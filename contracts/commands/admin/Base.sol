// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, Execution, Executions, Flags, Specs} from "../Base.sol";
import {NodeAccess} from "../../core/Access.sol";

/// @title AdminBase
/// @notice Shared base for admin commands.
abstract contract AdminBase is NodeAccess, CommandBase {
    /// @notice Open and authorize one admin command context.
    function openAdminCommand(
        bytes calldata context,
        uint descriptor
    ) internal view returns (Execution memory exec) {
        exec = openCommand(context, descriptor);
        enforceAdmin(exec.account, msg.sender);
    }
}
