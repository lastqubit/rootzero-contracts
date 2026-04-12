// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {OperationBase} from "../core/Operation.sol";
import {Cur} from "../Cursors.sol";
import {CommandEvent} from "../events/Command.sol";
import {State} from "../utils/State.sol";
import {Ids, Selectors} from "../utils/Ids.sol";

/// @notice Execution context passed to every command invocation.
struct CommandContext {
    /// @dev Destination command node ID; zero means "any command on this host".
    uint target;
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
abstract contract CommandBase is OperationBase, CommandEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();
    /// @dev Thrown when `onlyAdmin` finds that `account` is not the admin account.
    error NotAdmin();
    /// @dev Thrown when `onlyCommand` finds that `target` does not match this command's ID.
    error UnexpectedEndpoint();

    /// @dev Restrict execution to calls where `account` is the host's admin account.
    modifier onlyAdmin(bytes32 account) {
        if (account != adminAccount) revert NotAdmin();
        _;
    }

    /// @dev Restrict execution to trusted callers targeting this specific command.
    /// A zero `target` is treated as a wildcard and matches any command.
    /// @param cid This command's node ID (from `commandId`).
    /// @param target Requested destination from the `CommandContext`.
    modifier onlyCommand(uint cid, uint target) {
        if (target != 0 && target != cid) revert UnexpectedEndpoint();
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
    /// The ID encodes the ABI selector of `name((uint256,bytes32,bytes,bytes))` and
    /// `address(this)`, making it unique per (function name, contract address) pair.
    /// @param name Command function name (without argument list).
    /// @return Command node ID.
    function commandId(string memory name) internal view returns (uint) {
        return Ids.toCommand(Selectors.command(name), address(this));
    }
}
