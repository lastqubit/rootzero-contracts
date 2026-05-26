// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeCalls} from "../core/Calls.sol";
import {CommandEvent} from "../events/Command.sol";
import {Keys} from "../blocks/Keys.sol";
import {Ids, Selectors} from "../utils/Ids.sol";

/// @notice Execution context passed to every command invocation.
struct CommandContext {
    /// @dev Caller's account identifier.
    bytes32 account;
    /// @dev Current state block stream (previous command output or initial state).
    bytes state;
    /// @dev Input block stream for this invocation.
    bytes request;
}

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers, event emission, and the `commandId`
/// helper used to derive stable identifiers for named commands.
abstract contract CommandBase is NodeCalls, CommandEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();

    /// @dev Restrict execution to the commander using the host's admin account.
    modifier onlyAdmin(bytes32 account) {
        if (account != admin) revert AccessDenied();
        enforceCommander(msg.sender);
        _;
    }

    /// @dev Restrict execution to trusted callers.
    modifier onlyCommand() {
        enforceCaller(msg.sender);
        _;
    }

    /// @dev Restrict execution to invocations where `deadline` is in the future.
    /// @param deadline Unix timestamp after which the invocation is considered expired.
    modifier onlyActive(uint deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    /// @notice Derive the deterministic node ID for a named command on this contract.
    /// The ID encodes the ABI selector of `name((bytes32,bytes,bytes))` and
    /// `address(this)`, making it unique per (function name, contract address) pair.
    /// @param name Command function name (without argument list).
    /// @return Command node ID.
    function commandId(string memory name) internal view returns (uint) {
        return Ids.toCommand(Selectors.command(name), address(this));
    }
}
