// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CallerAccess} from "../core/Access.sol";
import {EndpointBase} from "../core/Endpoint.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Specs} from "../codec/Specs.sol";
import {HostAmount, Position} from "../core/Types.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {ReceivedEvent} from "../events/Received.sol";
import {Actions} from "../utils/Actions.sol";
import {Descriptors, Flags} from "../codec/Descriptors.sol";
import {Nodes} from "../utils/Nodes.sol";
import {Cursors} from "../utils/Cursors.sol";

using Executions for Execution;

/// @title CommandBase
/// @notice Abstract base for all rootzero command contracts.
/// Provides access control modifiers and command endpoint metadata helpers.
abstract contract CommandBase is CallerAccess, EndpointBase, ReceivedEvent {
    /// @dev Thrown when `onlyActive` finds that `deadline` has already passed.
    error Expired();
    /// @dev Thrown when a non-funded internal command receives native value.
    error ValueNotAllowed();

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
    /// @param flags Packed command behavior flags.
    /// @return id Command node ID.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function command(
        string memory name,
        uint state,
        uint input,
        uint output,
        uint8 transactions,
        uint8 flags
    ) internal returns (uint id, uint descriptor) {
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
        id = Nodes.toCommand(name, address(this));
        published = endpoint(id, name, descriptor);
    }

    /// @notice Decode the command ABI argument as exactly one complete CONTEXT block.
    /// @dev Rejects empty input, trailing bytes, and additional context blocks.
    function unpackCommandContext(
        bytes calldata context
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata input) {
        uint abs;
        assembly ("memory-safe") {
            abs := context.offset
        }

        uint end;
        (account, state, input, end) = Blocks.unpackContext(abs);
        if (end != abs + context.length) revert Blocks.InvalidBlock();
    }

    /// @notice Decode one command context and validate both lanes, including lanes declared EMPTY.
    /// Batches are derived from the input and state lanes. A non-empty stream for
    /// a lane whose descriptor has zero stride reverts instead of being ignored.
    /// Commands must account for the complete validated state by consuming it,
    /// transforming and returning it, forwarding it intact, or reverting.
    /// @param context Exactly one CONTEXT block carrying the account, state, and input.
    /// @param descriptor Packed command endpoint descriptor.
    /// @param batches Required batch count, or zero to reconcile the lane counts.
    /// @return exec Execution with its output buffer metadata initialized for the reconciled batch count.
    function openCommand(
        bytes calldata context,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        bytes32 account;
        bytes calldata state;
        bytes calldata input;
        (account, state, input) = unpackCommandContext(context);
        exec = Executions.open(state, input, descriptor, batches);
        exec.account = account;
    }

    /// @notice Close a command execution and refund unspent value to its account.
    /// @param exec Command execution to close.
    /// @return output Final encoded output block stream.
    /// @return transactions Final encoded transaction block stream.
    function closeCommand(
        Execution memory exec
    ) internal returns (bytes memory output, bytes memory transactions) {
        if (exec.budget == 0 && Cursors.initial(exec.writers)) return ("", "");

        output = close(exec);
        uint amount = exec.refundValue(exec.account, nativeAsset);
        if (amount != 0) {
            emit Received(exec.account, nativeAsset, amount, Actions.Refund, 0);
        }

        transactions = exec.finishTransactions();
    }
}
