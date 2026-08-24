// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, Execution, Executions, Flags, Lanes, Specs} from "../Base.sol";
import {NodeAccess} from "../../core/Access.sol";

/// @title AdminBase
/// @notice Shared base for admin commands.
abstract contract AdminBase is NodeAccess, CommandBase {
    /// @notice Decode, authorize, and open one admin command context.
    function openAdminCommand(
        bytes calldata context,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        (bytes32 account, bytes calldata state, bytes calldata input) = unpackCommandContext(context);
        enforceAdmin(account, msg.sender);
        exec = Executions.open(state, input, descriptor, batches);
        exec.account = account;
    }
}
