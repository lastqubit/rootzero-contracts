// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, Execution, Executions, Flags, Lanes, Specs} from "../Base.sol";
import {NodeAccess} from "../../core/Access.sol";

/// @title AdminBase
/// @notice Shared base for admin commands.
abstract contract AdminBase is NodeAccess, CommandBase {
    /// @dev Restrict execution to the commander using the host's admin account.
    modifier onlyAdmin(bytes32 account) {
        enforceAdmin(account, msg.sender);
        _;
    }
}
