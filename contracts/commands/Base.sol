// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeCalls} from "../core/Calls.sol";
import {Cur} from "../Cursors.sol";
import {CommandEvent} from "../events/Command.sol";
import {Keys} from "../blocks/Keys.sol";
import {Ids, Selectors} from "../utils/Ids.sol";
import {Budget, Values} from "../utils/Value.sol";

/// @notice Execution context passed to every command invocation.
struct CommandContext {
    /// @dev Caller's account identifier.
    bytes32 account;
    /// @dev Current state block stream (previous command output or initial state).
    bytes state;
    /// @dev Input block stream for this invocation.
    bytes request;
}

/// @notice ABI-encode a command call from a command ID and execution context.
/// @dev Derives the function selector from `cid` via `Ids.commandSelector(cid)`.
/// Reverts if `cid` is not a valid command ID.
/// @param cid Command node ID embedding the target selector.
/// @param account Caller account identifier for the command context.
/// @param state Current state block stream passed to the command.
/// @param request Input block stream for the command invocation.
/// @return ABI-encoded calldata for the command entry point.
function encodeCommandCall(
    uint cid,
    bytes32 account,
    bytes memory state,
    bytes calldata request
) pure returns (bytes memory) {
    bytes4 selector = Ids.commandSelector(cid);
    CommandContext memory ctx = CommandContext(account, state, request);
    return abi.encodeWithSelector(selector, ctx);
}

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers, event emission, and the `commandId`
/// helper used to derive stable identifiers for named commands.
abstract contract CommandBase is NodeCalls, CommandEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();
    /// @dev Thrown when the raw active account word in calldata does not match the decoded context account.
    error ActiveAccountMismatch();
    /// @dev Thrown when `onlyAdmin` finds that `account` is not the admin account.
    error NotAdmin();

    /// @dev Restrict execution to trusted callers whose decoded context account matches the active calldata account.
    modifier onlyCommand(bytes32 account) {
        if (activeAccount() != account) revert ActiveAccountMismatch();
        enforceCaller(msg.sender);
        _;
    }

    /// @dev Restrict execution to trusted callers using the host's admin account.
    modifier onlyAdmin(bytes32 account) {
        if (activeAccount() != account) revert ActiveAccountMismatch();
        if (account != adminAccount) revert NotAdmin();
        enforceCaller(msg.sender);
        _;
    }

    /// @dev Restrict execution to callers whose host node is trusted.
    modifier onlyTrusted() {
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

    /// @notice Return the active command account directly from the fixed tuple head in calldata.
    /// @dev Command entrypoints use the ABI shape `name((bytes32,bytes,bytes))`, so the tuple head
    /// starts at byte 36 of `msg.data`, with the account field at bytes [36:68).
    function activeAccount() internal pure returns (bytes32 account) {
        account = bytes32(msg.data[36:68]);
    }
}

/// @title CommandPayable
/// @notice Abstract base for commands that accept native value (`msg.value`).
/// Provides a shared settlement hook for any unspent value remaining in the
/// command's mutable budget after execution completes.
abstract contract CommandPayable is CommandBase {
    /// @dev Thrown when a payable command completes with unspent native value.
    /// Override `settleValue` to implement refund or forwarding behavior instead.
    error UnusedValue(uint remaining);

    /// @notice Drains the command budget and settles any remaining native value.
    /// @dev Calls the amount-based `settleValue` hook only when some value remains.
    /// @param account Caller's account identifier for the current invocation.
    /// @param budget Mutable native-value budget used during command execution.
    function settleValue(bytes32 account, Budget memory budget) internal {
        uint remaining = Values.drain(budget);
        if (remaining != 0) settleValue(account, remaining);
    }

    /// @notice Handles leftover native value after a payable command has finished.
    /// @dev Override this hook to refund or redirect unused value for a command.
    /// The default implementation rejects any leftover amount.
    /// @param account Caller's account identifier for the current invocation.
    /// @param remaining Unspent native value left in the budget, in wei.
    function settleValue(bytes32 account, uint remaining) internal virtual {
        account;
        revert UnusedValue(remaining);
    }
}
