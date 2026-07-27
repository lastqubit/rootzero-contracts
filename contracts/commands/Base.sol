// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {NodeCalls} from "../core/Calls.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Keys} from "../codec/Keys.sol";
import {Specs} from "../codec/Specs.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {ReceivedEvent} from "../events/Received.sol";
import {Actions} from "../utils/Actions.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Selectors} from "../utils/Selectors.sol";
import {Cursors} from "../utils/Cursors.sol";

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers and command endpoint metadata helpers.
abstract contract CommandBase is NodeCalls, EndpointBase, ReceivedEvent {
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

    /// @notice Close a command execution and refund unspent value to `account`.
    /// @param exec Command execution to close.
    /// @param account Account that should receive any unspent value.
    /// @return output Final encoded output block stream.
    /// @return transactions Final encoded transaction block stream.
    function closeCommand(
        Execution memory exec,
        bytes32 account
    ) internal returns (bytes memory output, bytes memory transactions) {
        if (exec.budget == 0 && Cursors.initial(exec.writers)) return ("", "");
        output = closeExecution(exec);
        transactions = endValue(exec, account);
    }

    /// @notice Drain a command execution budget into a credit-only TRANSACTION block.
    /// @dev Emits `Received` with `Actions.Refund` when a transaction is created.
    /// @param exec Mutable execution whose remaining budget is drained.
    /// @param account Destination account to credit with the remaining native value.
    /// @return transaction Encoded TRANSACTION block, or empty bytes when the budget is empty.
    function endValue(
        Execution memory exec,
        bytes32 account
    ) internal returns (bytes memory transaction) {
        uint amount = exec.budget;
        exec.budget = 0;
        if (amount == 0) return "";

        transaction = Blocks.transaction(bytes32(0), account, nativeAsset, amount);
        emit Received(account, nativeAsset, amount, Actions.Refund, 0);
    }

    /// @notice Publish command metadata and a default label.
    /// @param name Default human-readable command label and selector name.
    /// @param state State block specification.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param selector Command ABI selector, or zero to derive it from `name`.
    /// @param funded Whether the command accepts nonzero native value.
    /// @param admin Whether the command is restricted to the admin account.
    /// @return id Command node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function command(
        string memory name,
        uint state,
        uint input,
        uint output,
        bytes4 selector,
        bool funded,
        bool admin
    ) internal returns (uint id, uint descriptor) {
        selector = selector == bytes4(0) ? Selectors.command(name) : selector;
        id = Nodes.toCommand(selector, address(this));
        descriptor = endpoint(id, name, state, input, output, funded, admin);
    }

    /// @notice Open a command state stream and return the expected output block count.
    /// @param source State block stream to open.
    /// @param descriptor Packed command endpoint descriptor.
    /// @param batches Required batch count, or zero to accept the state count.
    /// @return exec Execution with its output buffer metadata initialized for the state batch count.
    function openState(
        bytes calldata source,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return Executions.openState(source, descriptor, batches);
    }

    /// @notice Open a command execution with batches derived from its input and state lanes.
    /// @param state Current command state block stream.
    /// @param input Command input block stream.
    /// @param descriptor Packed command endpoint descriptor.
    /// @param batches Required batch count, or zero to reconcile the lane counts.
    /// @return exec Execution with its output buffer metadata initialized for the reconciled batch count.
    function openCommand(
        bytes calldata state,
        bytes calldata input,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return Executions.open(state, input, descriptor, batches);
    }
}
