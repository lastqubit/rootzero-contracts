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

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers, event emission, and the `commandId`
/// helper used to derive stable identifiers for named commands.
abstract contract CommandBase is NodeCalls, CommandEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();
    /// @dev Thrown when `onlyAdmin` finds that `account` is not the admin account.
    error NotAdmin();

    /// @dev Restrict execution to trusted callers.
    modifier onlyCommand() {
        enforceCaller(msg.sender);
        _;
    }

    /// @dev Restrict execution to trusted callers using the host's admin account.
    modifier onlyAdmin(bytes32 account) {
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

}

/// @title Payable
/// @notice Abstract mixin for entrypoints that accept native value (`msg.value`).
/// Provides a shared settlement hook for any unspent value remaining in the
/// mutable budget after execution completes.
abstract contract Payable {
    /// @dev Thrown when a payable entrypoint completes with unspent native value.
    /// Override `settleValue` to implement refund or forwarding behavior instead.
    error UnusedValue(uint remaining);

    /// @notice Create a native-value budget from the current call's `msg.value`.
    /// @return Budget initialised with the full `msg.value`.
    function valueBudget() internal view returns (Budget memory) {
        return Budget({remaining: msg.value});
    }

    /// @notice Deduct `amount` from the budget and return it.
    /// @param budget Mutable budget to deduct from.
    /// @param amount Native value to spend.
    /// @return The same `amount`, ready to forward to a callee.
    function useValue(Budget memory budget, uint amount) internal pure returns (uint) {
        return Values.use(budget, amount);
    }

    /// @notice Drains the budget and settles any remaining native value.
    /// @dev Calls the amount-based `settleValue` hook only when some value remains.
    /// @param account Account identifier for the current invocation.
    /// @param budget Mutable native-value budget used during execution.
    function settleValue(bytes32 account, Budget memory budget) internal {
        uint value = budget.remaining;
        if (value == 0) return;
        budget.remaining = 0;
        settleValue(account, value);
    }

    /// @notice Handles leftover native value after payable execution has finished.
    /// @dev Override this hook to refund or redirect unused value.
    /// The default implementation rejects any leftover amount.
    /// @param account Account identifier for the current invocation.
    /// @param remaining Unspent native value left in the budget, in wei.
    function settleValue(bytes32 account, uint remaining) internal virtual {
        account;
        revert UnusedValue(remaining);
    }
}
