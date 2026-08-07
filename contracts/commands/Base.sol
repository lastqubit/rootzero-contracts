// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CallerAccess} from "../core/Access.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Specs} from "../codec/Specs.sol";
import {HostAmount} from "../core/Types.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {ReceivedEvent} from "../events/Received.sol";
import {Actions} from "../utils/Actions.sol";
import {Descriptors} from "../codec/Descriptors.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Selectors} from "../utils/Selectors.sol";
import {Cursors} from "../utils/Cursors.sol";

using Executions for Execution;

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers and command endpoint metadata helpers.
abstract contract CommandBase is CallerAccess, EndpointBase, ReceivedEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();

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

    /// @notice Publish command metadata and a default label.
    /// @param name Command entrypoint name and default label. It must exactly
    /// match the Solidity command function name used by the canonical ABI.
    /// @param state State block specification.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param transactions Number of transaction blocks produced per batch, or zero for none.
    /// @param funded Whether the command accepts nonzero native value.
    /// @param admin Whether the command is restricted to the admin account.
    /// @return id Command node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function command(
        string memory name,
        uint state,
        uint input,
        uint output,
        uint8 transactions,
        bool funded,
        bool admin
    ) internal returns (uint id, uint descriptor) {
        uint8 flags = 0;
        if (funded) flags |= Descriptors.Funded;
        if (admin) flags |= Descriptors.Admin;
        descriptor = Descriptors.create(state, input, output, transactions, flags);
        return command(name, descriptor);
    }

    /// @notice Publish an already constructed command descriptor and default label.
    /// @param name Command entrypoint name and default label. It must exactly
    /// match the Solidity command function name used by the canonical ABI.
    /// @param descriptor Packed command endpoint descriptor.
    /// @return id Command node ID.
    /// @return published Published endpoint descriptor.
    function command(string memory name, uint descriptor) internal returns (uint id, uint published) {
        id = Nodes.toCommand(Selectors.command(name), address(this));
        published = endpoint(id, name, descriptor);
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

    /// @notice Close a command execution and refund unspent value to `account`.
    /// @param exec Command execution to close.
    /// @param account Account that should receive any unspent value.
    /// @return output Final encoded output block stream.
    /// @return transactions Final encoded transaction block stream.
    function close(
        Execution memory exec,
        bytes32 account
    ) internal returns (bytes memory output, bytes memory transactions) {
        if (exec.budget == 0 && Cursors.initial(exec.writers)) return ("", "");

        output = close(exec);
        uint amount = exec.refundValue(account, nativeAsset);
        if (amount != 0) {
            emit Received(account, nativeAsset, amount, Actions.Refund, 0);
        }

        transactions = exec.finishTransactions();
    }
}
